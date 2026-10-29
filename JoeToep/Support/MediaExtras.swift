// V21 — Extra's voor elke mediaspeler (YouTube, Twitch, Vimeo, SoundCloud, …):
//  • Volumeboost tot 300 % (Web Audio-versterker per video, zachte begrenzer tegen vervorming)
//  • Alleen audio: beeld verbergen (scheelt batterij/GPU) terwijl het geluid doorspeelt
//  • Herhalen (loop) van de huidige video
//  • Huidig frame opslaan als afbeelding
// De toestand wordt per tab onthouden en na het laden van een nieuwe pagina opnieuw toegepast.
import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class MediaExtras: ObservableObject {
    static let shared = MediaExtras()
    struct State: Equatable { var boost: Double = 1; var audioOnly = false; var loop = false }
    @Published private(set) var states: [ObjectIdentifier: State] = [:]

    func state(for session: WebSession) -> State { states[ObjectIdentifier(session)] ?? State() }

    func setBoost(_ value: Double, on session: WebSession) {
        var s = state(for: session); s.boost = value.clamped(1, 3); states[ObjectIdentifier(session)] = s
        apply(s, to: session)
    }
    func toggleAudioOnly(on session: WebSession) {
        var s = state(for: session); s.audioOnly.toggle(); states[ObjectIdentifier(session)] = s
        apply(s, to: session)
    }
    func toggleLoop(on session: WebSession) {
        var s = state(for: session); s.loop.toggle(); states[ObjectIdentifier(session)] = s
        apply(s, to: session)
    }
    /// Na een nieuwe pagina opnieuw toepassen (alleen als er iets aan staat).
    func reapply(to session: WebSession) {
        let s = state(for: session)
        guard s != State() else { return }
        apply(s, to: session)
    }

    private func apply(_ s: State, to session: WebSession) {
        session.webView.evaluateJavaScript("(\(Self.script))(\(s.boost),\(s.audioOnly),\(s.loop))", completionHandler: nil)
    }

    /// Het huidige videobeeld als PNG (werkt niet bij DRM-beveiligde video's).
    func captureFrame(from session: WebSession) {
        let js = """
        (()=>{try{const v=document.querySelector('video.html5-main-video')||document.querySelector('video');if(!v||!v.videoWidth)return null;
        const c=document.createElement('canvas');c.width=v.videoWidth;c.height=v.videoHeight;c.getContext('2d').drawImage(v,0,0);
        return c.toDataURL('image/png');}catch(e){return null}})()
        """
        session.webView.evaluateJavaScript(js) { value, _ in
            Task { @MainActor in
                guard let text = value as? String, let comma = text.firstIndex(of: ","),
                      let data = Data(base64Encoded: String(text[text.index(after: comma)...])) else {
                    session.showNotice(.information, "Frame not available", "This video is protected; its picture can't be saved.")
                    return
                }
                let name = "JoeToep frame \(Int(Date().timeIntervalSince1970)).png"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try? data.write(to: url)
                #if os(macOS)
                let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [.png]
                if panel.runModal() == .OK, let target = panel.url {
                    try? FileManager.default.removeItem(at: target); try? FileManager.default.copyItem(at: url, to: target)
                }
                #else
                let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
                var top = root; while let next = top?.presentedViewController { top = next }
                sheet.popoverPresentationController?.sourceView = top?.view
                top?.present(sheet, animated: true)
                #endif
            }
        }
    }

    /// (boost, audioOnly, loop) → op het hoofdmedia-element toepassen.
    static let script = #"""
    function(boost,audioOnly,loop){try{
    const m=[...document.querySelectorAll('video,audio')];
    const v=document.querySelector('video.html5-main-video')||m.find(x=>!x.paused)||m[0];
    let st=document.getElementById('joetoep-audio-only');
    if(audioOnly&&!st){st=document.createElement('style');st.id='joetoep-audio-only';
      st.textContent='video{opacity:0!important}.html5-video-player,#movie_player{background:#000!important}';
      (document.head||document.documentElement).appendChild(st);}
    if(!audioOnly&&st)st.remove();
    if(!v)return 0;
    v.loop=!!loop;
    if(boost>1.001||v.__jtGain){
      const AC=window.AudioContext||window.webkitAudioContext;
      if(!v.__jtGain&&AC){const ctx=new AC();const src=ctx.createMediaElementSource(v);const g=ctx.createGain();
        const comp=ctx.createDynamicsCompressor();comp.threshold.value=-6;comp.knee.value=6;comp.ratio.value=8;
        src.connect(g);g.connect(comp);comp.connect(ctx.destination);v.__jtGain=g;v.__jtCtx=ctx;
        v.addEventListener('play',()=>{try{ctx.resume()}catch(_){}});}
      if(v.__jtGain){v.__jtGain.gain.value=Math.max(1,Math.min(3,boost));try{v.__jtCtx.resume()}catch(_){}}
    }
    }catch(_){}return 0}
    """#
}
