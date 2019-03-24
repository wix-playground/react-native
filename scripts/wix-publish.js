require('shelljs/global');
const _ = require('lodash');
const semver = require('semver');
const release = require('./bump-oss-version');


publishWixReactNative();

function publishWixReactNative(){
  const releaseVersion = generateVersion();
  const releaseVersionNew = generateVersionNew();

  set('-e');
  echo(`Building4 ${releaseVersion}, make sure you are using the private artifactory credentials`);
  release.bumpVersion(releaseVersion.version);
  exec('./gradlew :ReactAndroid:installArchives --debug --stacktrace');

  echo(`Publishing to npm ${releaseVersion}... fake`);
  //exec('npm publish');

  echo(`commitAndPush ${releaseVersion}... fake`);
  //release.commitAndPush(releaseVersion.version);

  echo(`##teamcity[version: ${releaseVersion}]`);
}


function generateVersion() {
  let currentVersion = require('../package.json').version;
  let newVersion = semver.parse(currentVersion);
  newVersion.patch += 100;
  newVersion.version = `${newVersion.major}.${newVersion.minor}.${newVersion.patch}`;
  newVersion.raw = newVersion.version;
  return newVersion;
}

function generateVersionNew() {
  let currentVersion = require('../package.json').version;
  let releaseVersion = semver.parse(currentVersion);
  let wixMajor = 1;
  let wixMinor = 0;

  const numberAndCounter = _.split(process.env.BUILD_NUMBER, '#');
  const buildCounter = _.get(numberAndCounter, [1], 1);

  releaseVersion.version = `${releaseVersion.major}.${releaseVersion.minor}.${releaseVersion.patch}-wix.${wixMajor}.${wixMinor}-build.${buildCounter}`;
  echo(`newVersion: ${releaseVersion.version}`);
  return releaseVersion;
}


