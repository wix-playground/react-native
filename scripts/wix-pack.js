'use strict';

/*eslint-disable no-undef */
require('shelljs/global');

let releaseVersion = require('../package.json').version;

// -------- Generating Android Artifacts with JavaDoc
if (exec('./gradlew clean :ReactAndroid:installArchives').code) {
  console.log('Couldn\'t generate artifacts');
  exit(1);
}

// undo uncommenting javadoc setting
exec('git checkout ReactAndroid/gradle.properties');

console.log('Generated artifacts for Maven');

let artifacts = ['-javadoc.jar', '-sources.jar', '.aar', '.pom'].map((suffix) => {
  return `react-native-${releaseVersion}${suffix}`;
});

artifacts.forEach((name) => {
  if (!test('-e', `./android/com/facebook/react/react-native/${releaseVersion}/${name}`)) {
    console.log(`file ${name} was not generated`);
    exit(1);
  }
});

exec('npm pack');
/*eslint-enable no-undef */