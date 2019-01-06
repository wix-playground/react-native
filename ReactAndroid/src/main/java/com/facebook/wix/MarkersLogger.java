package com.facebook.wix;

import android.os.Process;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.view.ViewTreeObserver;

import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactMarker;
import com.facebook.react.bridge.ReactMarkerConstants;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.uimanager.util.ReactFindViewUtil;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.LinkedList;
import java.util.List;

import javax.annotation.Nullable;

/**
 * An extended implementation of
 * <a href="http://blog.nparashuram.com/2018/11/react-native-performance-playbook-part-i.html">Parashuram's performance logger</a>.
 *
 * <p/>Provides a unified, single-source logging machine for two type of events:
 * <ol>
 *     <li>React-native core events, as specified by the {@link ReactMarker} class (logged automatically).</li>
 *     <li>Custom, free-style events specified manually by the user using dedicated API's (e.g. {@link #logCustomEventMarker(String, String)},
 *         {@link #logCustomStartMarker(String, String)}, {@link #logCustomEventMarker(String, String)}).</li>
 * </ol>
 * Implemented as a <i>singleton</i> so as to allow for logging from any piece of code that's react-native aware.
 *
 * <h2>To set up:</h2>
 * 1. Put this <b>in the first line</b> of {@code Application.onCreate()}:
 * <pre>{@code
 * MarkersLogger.createInstance(System.currentTimeMillis(), new ReactContextProvider() {
 *       @Override
 *       public ReactContext getRNContext() {
 *         return reactContext; // TODO change so it would return the runtime RN context, typically: getReactNativeHost().getReactInstanceManager().getCurrentReactContext()
 *       }
 *     });
 * }</pre>
 *
 * <br/>2. Decide on the JS React component upon which rendering logging should be concluded (aka TTI completion); Add
 * {@code nativeID="tti_complete"} prop to it (or effective log would be empty).
 *
 * <h2>To have the logs finalized upon TTI completion:</h2>
 * {@code require('react-native/wix/markersLogger')} at the earliest point of your JS code possible.
 *
 * <h2>To fetch logs after device launch completes:</h2>
 * On a terminal, run an adb command that looks something like this:<br/>
 * {@code adb pull /sdcard/Android/data/com.android-package-prefix/files/trace.json}
 */
public class MarkersLogger {

  private static final String TAG = MarkersLogger.class.getSimpleName();

  public static final String LOG_READY_JS_EVENT = "MarkersLog.ready";
  public static final String JS_VARIABLE_NAME = "AXE_PERFLOGGER";
  public static final String BIRTH_TIME_EVENT_NAME = "BEGINNING_OF_TIME";

  protected static class UnifiedLogRecord {
    private final long mTime;
    private final String mName;
    private final String mTag;
    private final int mInstanceKey;
    private final int mTid;
    private final int mPid;

    UnifiedLogRecord(String name, String tag, int instanceKey) {
      mTime = System.currentTimeMillis();
      mName = name;
      mTag = tag;
      mInstanceKey = instanceKey;
      mPid = Process.myPid();
      mTid = Process.myTid();
    }

    UnifiedLogRecord(String name, String tag, int instanceKey, long time) {
      mTime = time;
      mName = name;
      mTag = tag;
      mInstanceKey = instanceKey;
      mPid = Process.myPid();
      mTid = Process.myTid();
    }

    public JSONObject toJSON() {
      final JSONObject result = new JSONObject();
      try {
        result.put("time", mTime);
        result.put("name", mName);
        result.put("tag", mTag);
        result.put("instanceKey", mInstanceKey);
        result.put("pid", mPid);
        result.put("tid", mTid);
        return result;
      } catch (JSONException e) {
        return null;
      }
    }

    public String toString() {
      return TextUtils.join(
          ",",
          new String[] {
            Long.toString(mTime),
            mName,
            mTag,
            Integer.toString(mInstanceKey),
            Integer.toString(mTid),
            Integer.toString(mPid)
          });
    }
  }

  public interface ReactContextProvider {
    ReactContext getRNContext();
  }

  private final long mStartTime;
  private final List<UnifiedLogRecord> mLog = new LinkedList<>();
  private final ReactContextProvider mReactContextProvider;

  private static MarkersLogger sInstance;

  /**
   * Create the logger instance. Call this once in Application.onCreate().
   *
   * @param globalStartTime Logging-universe' 0-time.
   * @param reactContextProvider A provider that could provide the React context, upon logging completion.
   */
  public static void createInstance(Long globalStartTime, ReactContextProvider reactContextProvider) {
    sInstance = new MarkersLogger(globalStartTime, reactContextProvider);
    sInstance.initialize();
    sInstance.logCustomEventMarker(BIRTH_TIME_EVENT_NAME, null, globalStartTime);
  }

  public static void createInstance(Long globalStartTime, final ReactContext reactContext) {
    createInstance(globalStartTime, new ReactContextProvider() {
      @Override
      public ReactContext getRNContext() {
        return reactContext;
      }
    });
  }

  public static MarkersLogger getInstance() {
    return sInstance;
  }

  public void logCustomStartMarker(String name) {
    logCustomStartMarker(name, null, System.currentTimeMillis());
  }

  public void logCustomStartMarker(String name, String tag) {
    logCustomStartMarker(name, tag, System.currentTimeMillis());
  }

  public void logCustomStartMarker(String name, String tag, Long time) {
    logCustomMarker("@" + name + "_START", tag, time);
  }

  public void logCustomEndMarker(String name) {
    logCustomEndMarker(name, null, System.currentTimeMillis());
  }

  public void logCustomEndMarker(String name, String tag) {
    logCustomEndMarker(name, tag, System.currentTimeMillis());
  }

  public void logCustomEndMarker(String name, String tag, Long time) {
    logCustomMarker("@" + name + "_END", tag, time);
  }

  public void logCustomEventMarker(String name, String tag) {
    logCustomMarker(name, tag, System.currentTimeMillis());
  }

  public void logCustomEventMarker(String name, String tag, Long time) {
    logCustomMarker(name, tag, time);
  }

  protected void logCustomMarker(String name, String tag, Long time) {
    mLog.add(new UnifiedLogRecord(name, tag, -1, time));
  }

  protected MarkersLogger(Long startTime, ReactContextProvider rnHostProvider) {
    mStartTime = startTime;
    mReactContextProvider = rnHostProvider;
  }

  protected void initialize() {
    setReactMarkerListener();
    setTTIEndListener();
  }

  protected void setReactMarkerListener() {
    ReactMarker.addListener(
            new ReactMarker.MarkerListener() {
              @Override
              public void logMarker(ReactMarkerConstants name, @Nullable String tag, int instanceKey) {
                mLog.add(new UnifiedLogRecord(name.toString(), tag, instanceKey));
              }
            });
  }

  /**
   * Waits for Loading to complete, also called a Time-To-Interaction (TTI) event. To indicate TTI
   * completion, add a prop nativeID="tti_complete" to the component whose appearance indicates that
   * the initial TTI or loading is complete
   */
  protected void setTTIEndListener() {
    ReactFindViewUtil.addViewListener(
      new ReactFindViewUtil.OnViewFoundListener() {
        @Override
        public String getNativeId() {
          // This is the value of the nativeID property
          return "tti_complete";
        }

        @Override
        public void onViewFound(final View view) {
          // Once we find the view, we also need to wait for it to be drawn
          view.getViewTreeObserver()
              .addOnPreDrawListener( // TODO (axe) Should be OnDrawListener instead of this
                new ViewTreeObserver.OnPreDrawListener() {
                  @Override
                  public boolean onPreDraw() {
                    view.getViewTreeObserver().removeOnPreDrawListener(this);

                    logCustomEventMarker("TTI_COMPLETE", null);
                    setVariableForJS();
                    notifyJSVariableReady();
                    return true;
                  }
                });
          }
        });
  }

  protected void setVariableForJS() {
    final ReactContext reactContext = mReactContextProvider.getRNContext();
    reactContext.getCatalystInstance().setGlobalVariable(JS_VARIABLE_NAME, createLogsJSON(mStartTime, mLog));
  }

  protected void notifyJSVariableReady() {
    final ReactContext reactContext = mReactContextProvider.getRNContext();
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(LOG_READY_JS_EVENT, JS_VARIABLE_NAME);
  }

  protected String createLogsJSON(long startTime, @Nullable List<UnifiedLogRecord> records) {
    final JSONObject result = new JSONObject();
    try {
      result.put("startTime", startTime);
      if (records != null) {
        final JSONArray jsonRecords = new JSONArray();
        for (UnifiedLogRecord record : records) {
          jsonRecords.put(record.toJSON());
        }
        result.put("data", jsonRecords);
      }
      return result.toString();
    } catch (JSONException e) {
      Log.w(TAG, "Could not convert perf records to JSON", e);
      return "{}";
    }
  }
}
