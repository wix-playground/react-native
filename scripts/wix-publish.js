require('shelljs/global');
const semver = require('semver');

let currentVersion = require('../package.json').version;
let releaseVersion = semver.parse(currentVersion);
releaseVersion.patch += 100;
releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}`;
releaseVersion.raw = releaseVersion.version;

exec(`scripts/bump-oss-version.js ${releaseVersion}`);

// -------- Generating Android Artifacts with JavaDoc
if (exec('./gradlew clean :ReactAndroid:installArchives').code) {
  echo('Couldn\'t generate artifacts');
  exit(1);
}

exec('npm publish');
echo(`Published to npm ${releaseVersion}`);

exit(0);
