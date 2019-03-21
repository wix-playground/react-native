require('shelljs/global');
const semver = require('semver');
const release = require('./bump-oss-version');

const releaseVersion = generateVersion();
const releaseVersionNew = generateVersionNew();
echo(`newVersion: ${releaseVersionNew}`);

set('-e');

echo(`Building ${releaseVersion}, make sure you are using the private artifactory credentials`);
release.bumpVersion(releaseVersion.version);
exec('./gradlew :ReactAndroid:installArchives --debug');

echo(`Publishing to npm ${releaseVersion}...`);
exec('npm publish');

echo(`commitAndPush ${releaseVersion}...`);
release.commitAndPush(releaseVersion.version);

echo(`##teamcity[version: ${releaseVersion}]`);


function generateVersion() {
  let currentVersion = require('../package.json').version;
  let releaseVersion = semver.parse(currentVersion);
  releaseVersion.patch += 100;
  releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}`;
  releaseVersion.raw = releaseVersion.version;
}

function generateVersionNew() {
  let currentVersion = require('../package.json').version;
  let releaseVersion = semver.parse(currentVersion);
  let wixMajor = 1;
  let wixMinor = 0;

  const numberAndCounter = _.split(process.env.BUILD_NUMBER, '#');
  const buildCounter = _.get(numberAndCounter, [1], 1);

  releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}.-wix.${wixMajor}.${wixMinor}-build.${buildCounter}`;
  return releaseVersion.version;
}


