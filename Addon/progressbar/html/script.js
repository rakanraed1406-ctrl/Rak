document.addEventListener("DOMContentLoaded", function () {
    const ProgressBar = {
        progressLabel: null,
        progressIcon: null,
        progressBar: null,
        progressDot: null,
        progressContainer: null,
        progressPercentage: null,
        progressSeconds: null,
        animationFrameRequest: null,
        hideTimer: null,

        init: function () {
            this.progressLabel = document.getElementById("progress-label");
            this.progressIcon = document.getElementById("progress-icon");
            this.progressBar = document.getElementById("progress-bar");
            this.progressDot = document.getElementById("progress-dot");
            this.progressContainer = document.querySelector(".progress-container");
            this.progressPercentage = document.getElementById("progress-percentage");
            this.progressSeconds = document.getElementById("progress-seconds");

            window.addEventListener("message", (event) => {
                const data = event.data || {};

                if (data.action === "progress") {
                    this.startProgress(data);
                } else if (data.action === "cancel") {
                    this.cancel();
                }
            });
        },

        clearTimers: function () {
            if (this.animationFrameRequest) {
                cancelAnimationFrame(this.animationFrameRequest);
                this.animationFrameRequest = null;
            }

            if (this.hideTimer) {
                clearTimeout(this.hideTimer);
                this.hideTimer = null;
            }
        },

        setIcon: function (iconClass) {
            const safeIconClass = typeof iconClass === "string"
                ? iconClass.trim().replace(/[^a-zA-Z0-9 _-]/g, "")
                : "";

            this.progressIcon.replaceChildren();

            if (!safeIconClass) {
                const loader = document.createElement("div");
                loader.className = "progress-loader";
                this.progressIcon.appendChild(loader);
                return;
            }

            const icon = document.createElement("i");
            icon.className = safeIconClass;
            this.progressIcon.appendChild(icon);
        },

        setVisualProgress: function (percentage) {
            const safePercentage = Math.min(Math.max(percentage, 0), 100);
            this.progressBar.style.width = `${safePercentage}%`;
            this.progressDot.style.left = `${safePercentage}%`;
            this.progressPercentage.textContent = `${Math.round(safePercentage)}%`;
        },

        startProgress: function (data) {
            this.clearTimers();

            const duration = Math.max(Number.parseInt(data.duration, 10) || 0, 0);
            this.setVisualProgress(0);
            this.progressSeconds.textContent = `${Math.ceil(duration / 1000)}s`;
            this.progressLabel.textContent = data.label || "Processing...";
            this.setIcon(data.Icon || data.icon);

            this.progressContainer.style.display = "block";
            this.progressContainer.style.transition = "opacity 0.15s ease-in";
            this.progressContainer.style.opacity = "1";

            const startTime = performance.now();

            const animate = (currentTime) => {
                const elapsed = currentTime - startTime;
                const progress = duration > 0 ? Math.min(elapsed / duration, 1) : 1;
                const percentage = progress * 100;
                const remainingMs = Math.max(duration - elapsed, 0);

                this.setVisualProgress(percentage);
                this.progressSeconds.textContent = `${Math.ceil(remainingMs / 1000)}s`;

                if (progress < 1) {
                    this.animationFrameRequest = requestAnimationFrame(animate);
                } else {
                    this.animationFrameRequest = null;
                    this.onComplete();
                }
            };

            this.animationFrameRequest = requestAnimationFrame(animate);
        },

        hide: function () {
            this.progressContainer.style.transition = "opacity 0.15s ease-out";
            this.progressContainer.style.opacity = "0";

            this.hideTimer = setTimeout(() => {
                this.progressContainer.style.display = "none";
                this.setVisualProgress(0);
                this.progressSeconds.textContent = "0s";
                this.hideTimer = null;
            }, 150);
        },

        cancel: function () {
            this.clearTimers();
            this.hide();
        },

        onComplete: function () {
            this.postAction("FinishAction");
            this.hide();
        },

        postAction: function (action) {
            const resourceName = typeof GetParentResourceName === "function"
                ? GetParentResourceName()
                : "progressbar";

            fetch(`https://${resourceName}/${action}`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({}),
            }).catch(() => {});
        },
    };

    ProgressBar.init();
});
