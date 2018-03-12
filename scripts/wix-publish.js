/*eslint-disable no-undef */
require('shelljs/global');
const semver = require('semver');

let currentVersion = require('../package.json').version;
let releaseVersion = semver.parse(currentVersion);
releaseVersion.patch += 100;
releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}`;
releaseVersion.raw = releaseVersion.version;

// -------- Generating Android Artifacts with JavaDoc
if (exec('./gradlew clean :ReactAndroid:installArchives').code) {
  echo('Couldn\'t generate artifacts');
  exit(1);
}

exec(`scripts/bump-oss-version.js ${releaseVersion}`);

// undo uncommenting javadoc setting
exec('git checkout ReactAndroid/gradle.properties');

echo('Generated artifacts for Maven');

let artifacts = ['-javadoc.jar', '-sources.jar', '.aar', '.pom'].map((suffix) => {
  return `react-native-${releaseVersion}${suffix}`;
});

artifacts.forEach((name) => {
  if (!test('-e', `./android/com/facebook/react/react-native/${releaseVersion}/${name}`)) {
    echo(`file ${name} was not generated`);
    exit(1);
  }
});

exec('npm publish');
echo(`Published to npm ${releaseVersion}`);

exit(0);
/*eslint-enable no-undef */
