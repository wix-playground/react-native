'use strict';
const cp = require('child_process');

function exec(cmd) {
  cp.execSync(cmd, { stdio: ['inherit', 'inherit', 'inherit'] });
}

let releaseVersion = require('../package.json').version;

// -------- Generating Android Artifacts with JavaDoc
exec('./gradlew clean :ReactAndroid:installArchives');

// undo uncommenting javadoc setting
exec('git checkout ReactAndroid/gradle.properties');

console.log('Generated artifacts for Maven');

let artifacts = ['-javadoc.jar', '-sources.jar', '.aar', '.pom'].map((suffix) => {
  return `react-native-${releaseVersion}${suffix}`;
});

artifacts.forEach((name) => {
  exec(`test -e ./android/com/facebook/react/react-native/${releaseVersion}/${name}`)
});

exec('npm pack');
/*eslint-enable no-undef */