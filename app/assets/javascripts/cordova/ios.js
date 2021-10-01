/* 
 * Steps to generate ./ios/cordova.js
 *   1. Run 'cordova prepare ios --browserify' in ChronusMobile repo from appropriate branch
 *   2. cordova.js file will be generated at 'ChronusMobile/platforms/ios/www/cordova.js'
 *   3. Copy and place the same file generated in above step at './ios/cordova.js' in this repo
 * 
 * Regenerate cordova.js when,
 *   1. Cordova is upgraded
 *   2. Any plugin is added or removed in Cordova code base
 */
//= require ./ios/cordova
//= require ./ios/ios_plugins_helper