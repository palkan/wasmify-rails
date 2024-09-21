export class Progress {
  constructor() {
    this.listeners = new Set();
    this.currentStep = "Initializing...";
    this.currentValue = 0;
  }

  async attach(worker) {
    const clients = await worker.clients.matchAll({
      includeUncontrolled: true,
    });
    for (const client of clients) {
      this.addListener(client);
    }
  }

  addListener(listener) {
    this.listeners.add(listener);
  }

  removeListener(listener) {
    this.listeners.delete(listener);
  }

  notifyProgress() {
    for (const listener of this.listeners) {
      listener.postMessage({
        type: "progress",
        step: this.currentStep,
        value: this.currentValue,
      });
    }
  }

  notify(message) {
    for (const listener of this.listeners) {
      listener.postMessage({ type: "console", message });
    }
  }

  updateStep(step) {
    this.currentStep = step;
    this.currentValue = 0;
    this.notifyProgress();
  }

  updateProgress(value) {
    this.currentValue = value;
    this.notifyProgress();
  }
}
