import { NativeModules } from 'react-native'
const NowPlayingManager = NativeModules.NowPlayingManager

const STATE_PLAYING =  NowPlayingManager.STATE_PLAYING
const STATE_PAUSED = NowPlayingManager.STATE_PAUSED
const STATE_ERROR =  NowPlayingManager.STATE_ERROR
const STATE_STOPPED =  NowPlayingManager.STATE_STOPPED

export default {
  STATE_PLAYING,
  STATE_PAUSED,
  STATE_ERROR,
  STATE_STOPPED,
}
