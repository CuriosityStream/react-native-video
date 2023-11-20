// Unused import - only used to make this file a module (otherwise declare global won't work)
import React from "react";

// Extend HTMLImageElement to support extended module
declare module "react-native-video" {
    namespace NowPlayingManager {
        //@ts-ignore
        interface NowPlayingModuleInferface {
            setNowPlaying: (info: {artwork?: string, duration?: number, title?: string, externalContentID?: string }) => void;
            updatePlayback: (info: {speed?: number, state?: string, elapsedTime?: number }) => void;
            resetNowPlaying: () => void;
        }
        //@ts-ignore
        interface NowPlayingType {
            [key: string]: string
        }
    }
}