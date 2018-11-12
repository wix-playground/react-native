require('shelljs/global');
const semver = require('semver');

let currentVersion = require('../package.json').version;
let releaseVersion = semver.parse(currentVersion);
releaseVersion.patch += 100;
releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}`;
releaseVersion.raw = releaseVersion.version;

echo(`Building ${releaseVersion}, make sure you are using the private artifactory credentials`);
exec(`scripts/bump-oss-version.js ${releaseVersion}`);
//exec('./gradlew clean :ReactAndroid:installArchives');
//echo(`Publishing to npm ${releaseVersion}...`);
//exec('npm publish');
//echo(`Published to npm ${releaseVersion}`);
