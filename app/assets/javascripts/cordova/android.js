/* 
 * Steps to generate ./android/cordova.js
 *   1. Run 'cordova prepare android --browserify' in ChronusMobile repo from appropriate branch
 *   2. cordova.js file will be generated at 'ChronusMobile/platforms/android/assets/www/cordova.js'
 *   3. Copy and place the same file generated in above step at './android/cordova.js' in this repo
 * 
 * Regenerate cordova.js when,
 *   1. Cordova is upgraded
 *   2. Any plugin is added or removed in Cordova code base
 */
//= require ./android/cordova
//= require ./android/android_plugins_helper
