let shouldTrackMovement = false;
let isMouseInRedzone = false;
let stages = [];
let failCount = 0;
let maxFailCount = 3;

const updateRedzoneState = (state) => (isMouseInRedzone = state);

const generateRandom = (min, max) => {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min + 1)) + min;
};

const getHandleDegree = () => {
  let obj = $(".lockpick-handle");
  var matrix =
    obj.css("-webkit-transform") ||
    obj.css("-moz-transform") ||
    obj.css("-ms-transform") ||
    obj.css("-o-transform") ||
    obj.css("transform");
  if (matrix !== "none") {
    var values = matrix.split("(")[1].split(")")[0].split(",");
    var a = values[0];
    var b = values[1];
    var angle = Math.round(Math.atan2(b, a) * (180 / Math.PI));
  } else {
    var angle = 0;
  }
  return angle < 0 ? angle + 360 : angle;
};

const getCurrentStage = () => {
  let currentStage = null;

  for (let i = 0; i < stages.length; i++) {
    if (!stages[i].passed) {
      currentStage = stages[i];
      currentStage.index = i;
      break;
    }
  }

  return currentStage;
};

const isAllStagesPassed = () => {
  let allStagesPassed = true;
  for (let i = 0; i < stages.length; i++) {
    if (!stages[i].passed) allStagesPassed = false;
  }

  return allStagesPassed;
};

const passedStage = () => {};

const onLockpickHandleRotation = (degree, secondCheck) => {
  if (degree < 0) degree += 360;
  const stage = getCurrentStage();

  if (stage) {
    if (Math.abs(stage.degree - degree) < 40) {
      if (Math.abs(stage.degree - degree) < 20) {
        $(".lockpick-outer").css(
          "animation",
          "LockPicking 0.4s forwards infinite"
        );
      } else
        $(".lockpick-outer").css(
          "animation",
          "LockPicking 0.8s forwards infinite"
        );
    } else {
      $(".lockpick-outer").removeAttr("style");
    }
  }
};

const createGame = (stageAmount) => {
  for (let i = 0; i < stageAmount; i++) {
    stages.push({
      id: i,
      degree: generateRandom(1, 360),
      passed: false,
    });

    $(".stages").append(`<div id="stage-${i}" class="stage"></div>`);
  }
};

window.addEventListener("mousedown", (ev) => {
  if (ev.button === 0) {
    shouldTrackMovement = true;
  }
});

window.addEventListener("mouseup", (ev) => {
  if (ev.button === 0) {
    shouldTrackMovement = false;
  }
});

window.addEventListener("mousemove", (ev) => {
  if (!shouldTrackMovement || isMouseInRedzone) return;

  const handleCoords = document
    .getElementById("lockpick-handle")
    .getBoundingClientRect();

  let boxCenter = {
    x: handleCoords.left + handleCoords.width / 2,
    y: handleCoords.top + handleCoords.height / 2,
  };

  const degree =
    Math.atan2(ev.pageX - boxCenter.x, -(ev.pageY - boxCenter.y)) *
    (180 / Math.PI);

  $(".lockpick-handle").css("transform", `rotate(${degree}deg)`);

  onLockpickHandleRotation(degree);
});

// window.addEventListener("keydown", (ev) => {
  
// });

function handleKeys(ev){
  const currentRotation = getHandleDegree();
  switch (ev.code?.toUpperCase()) {
    case "KEYW":
      $(".lockpick-handle").css(
        "transform",
        `rotate(${currentRotation + 3}deg)`
      );
      onLockpickHandleRotation(getHandleDegree());
      break;
    case "ARROWUP":
        $(".lockpick-handle").css(
          "transform",
          `rotate(${currentRotation + 3}deg)`
        );
        onLockpickHandleRotation(getHandleDegree());
        break;
    case "KEYS":
      $(".lockpick-handle").css(
        "transform",
        `rotate(${currentRotation - 3}deg)`
      );
      onLockpickHandleRotation(getHandleDegree());
      break;
    case "ARROWDOWN":
      $(".lockpick-handle").css(
        "transform",
        `rotate(${currentRotation - 3}deg)`
      );
      onLockpickHandleRotation(getHandleDegree());
      break;
    case "ENTER":
      const stage = getCurrentStage();
      const degree = getHandleDegree();

      if (Math.abs(stage.degree - degree) <= 10) {
        shouldTrackMovement = false;

        $(".lockpick-outer").removeAttr("style");

        $(".lockpick-inner").addClass("lockpicked");

        stages[stage.index].passed = true;

        $(`#stage-${stage.id}`).addClass("stage-passed");

        const gameFinished = isAllStagesPassed();

        if (gameFinished) {
          $.post(`https://${GetParentResourceName()}/gameFinished`);
        } else {
          setTimeout(() => {
            $(".lockpick-inner").removeClass("lockpicked");
            $(".lockpick-handle").css("transform", "rotate(0deg)");
            $(".lockpick-outer").removeAttr("style");
          }, 500);
        }
      } else {
        $(".lockpick-inner").addClass("lockpick-failed");

        setTimeout(() => {
          shouldTrackMovement = false;

          if (failCount == maxFailCount)
            $.post(`https://${GetParentResourceName()}/failedGame`);

          $(".lockpick-inner").removeClass("lockpick-failed");
          $(".lockpick-handle").css("transform", "rotate(0deg)");
          $(".lockpick-outer").removeAttr("style");

          failCount++;
        }, 500);
      }
      break;
  }
}
$(document).on("keydown", handleKeys);

function handleEscKeyPress(event) {
  if (event.key === "Escape") {
    $.post(`https://${GetParentResourceName()}/failedGame`);
    $(".container").fadeOut();
    $(".lockpick-inner").removeClass("lockpicked");
    $(".lockpick-outer").removeAttr("style");
    $(".lockpick-handle").css("transform", "rotate(0deg)");
    $(".stage").remove();
    failCount = 0;
    stages = [];
  }
}

$(document).on("keyup", handleEscKeyPress);

window.addEventListener("message", ({ data }) => {
  switch (data?.action) {
    case "createGame":
      $(".container").fadeIn();
      maxFailCount = data?.maxFail ?? 4;
      createGame(data?.stages);
      break;

    case "endGame":
      $(".container").fadeOut();
      $(".lockpick-inner").removeClass("lockpicked");
      $(".lockpick-outer").removeAttr("style");
      $(".lockpick-handle").css("transform", "rotate(0deg)");
      $(".stage").remove();
      failCount = 0;
      stages = [];
      break;

    default:
      break;
  }
});
