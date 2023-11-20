

declare module "react-native-video" {
    export interface NowPlayingManager {
            setNowPlaying: (info: {artwork?: string, duration?: number, title?: string, externalContentID?: string }) => void;
            updatePlayback: (info: {speed?: number, state?: string, elapsedTime?: number }) => void;
            resetNowPlaying: () => void;
        }

    export interface NowPlayingType {
            [key: string]: string
        }
}