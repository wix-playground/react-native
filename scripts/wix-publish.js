require('shelljs/global');
const semver = require('semver');
const release = require('./bump-oss-version');
let currentVersion = require('../package.json').version;
let releaseVersion = semver.parse(currentVersion);
releaseVersion.patch += 100;
releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}`;
releaseVersion.raw = releaseVersion.version;

set('-e');
echo(`Building ${releaseVersion}, make sure you are using the private artifactory credentials`);
release.bumpVersion(releaseVersion.version);
exec('./gradlew :ReactAndroid:installArchives');
echo(`Publishing to npm ${releaseVersion}...`);
exec('npm publish');
release.commitAndPush(releaseVersion.version);
echo(`##teamcity[version: ${releaseVersion}]`);
