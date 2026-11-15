// MapMan web version: the phone's tilt for the game (scripts/motion.gd).
//
// Browsers don't hand motion sensors to Godot, so this keeps the latest
// devicemotion reading in window.mapmanMotion, in Godot's terms:
// m/s², pointing at the ground, rotated to the screen
// (+x right edge, +y top edge, +z out of the screen).
// g = gravity alone, a = gravity plus shakes.
(function () {
  var m = (window.mapmanMotion = { gx: 0, gy: 0, gz: 0, ax: 0, ay: 0, az: 0 });
  var ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  // The browser reports the push holding the phone up; Godot wants the pull
  // down. iOS Safari reports it the other way round already.
  var sign = ios ? 1 : -1;

  function angle() {
    if (screen.orientation && typeof screen.orientation.angle === "number") {
      return screen.orientation.angle;
    }
    return typeof window.orientation === "number" ? window.orientation : 0;
  }

  // Device axes (portrait) to screen axes.
  function turn(x, y) {
    var r = (angle() * Math.PI) / 180;
    var c = Math.cos(r), s = Math.sin(r);
    return [x * c - y * s, x * s + y * c];
  }

  var have = false;
  function onMotion(e) {
    var i = e.accelerationIncludingGravity;
    if (!i || i.x === null) return;
    var ax = sign * i.x, ay = sign * i.y, az = sign * i.z;
    var gx, gy, gz;
    var l = e.acceleration;
    if (l && l.x !== null) {
      gx = ax - sign * l.x; gy = ay - sign * l.y; gz = az - sign * l.z;
    } else {
      // No split from the browser: smooth the shakes out for gravity.
      var k = have ? 0.2 : 1;
      gx = m._dx === undefined ? ax : m._dx + (ax - m._dx) * k;
      gy = m._dy === undefined ? ay : m._dy + (ay - m._dy) * k;
      gz = m._dz === undefined ? az : m._dz + (az - m._dz) * k;
      m._dx = gx; m._dy = gy; m._dz = gz;
    }
    have = true;
    var a = turn(ax, ay), g = turn(gx, gy);
    m.ax = a[0]; m.ay = a[1]; m.az = az;
    m.gx = g[0]; m.gy = g[1]; m.gz = gz;
  }

  var listening = false;
  function listen() {
    if (listening) return;
    listening = true;
    window.addEventListener("devicemotion", onMotion);
  }

  // Most browsers send motion straight away.
  listen();
  // iPhone and iPad (and some newer browsers) send nothing until the player
  // allows it, and that can only be asked from a tap.
  if (typeof DeviceMotionEvent !== "undefined" &&
      typeof DeviceMotionEvent.requestPermission === "function") {
    var ask = function () {
      window.removeEventListener("touchend", ask, true);
      window.removeEventListener("click", ask, true);
      DeviceMotionEvent.requestPermission().catch(function () {});
    };
    window.addEventListener("touchend", ask, true);
    window.addEventListener("click", ask, true);
  }
})();
