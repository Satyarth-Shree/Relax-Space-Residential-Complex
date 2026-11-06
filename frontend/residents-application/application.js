// application.js
// Bridges application.html with the backend (via the frontend proxy at :8000).
// Dropdown options are fetched live from the backend endpoint
// /backend/room-seator instead of being hardcoded.

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("application-form");
  const select = document.getElementById("room_seator");
  const submitBtn = document.getElementById("submit-btn");
  const btnLabel = submitBtn.querySelector(".btn-label");
  const spinner = document.getElementById("spinner");
  const msg = document.getElementById("form-msg");

  const API_BASE = "/api"; // /api/* is transparently proxied to the FastAPI backend on :8001

  /* ---------------- Load room seater options dynamically ---------------- */
  async function loadRoomSeaterOptions() {
    select.disabled = true;
    try {
      const res = await fetch(`${API_BASE}/backend/room-seator`);
      if (!res.ok) throw new Error(`Server responded with status ${res.status}`);
      const data = await res.json();

      select.innerHTML =
        '<option value="" disabled selected>Select a room seater</option>';

      for (const choice of data.room_choices) {
        const opt = document.createElement("option");
        opt.value = choice;
        opt.textContent =
          choice.charAt(0).toUpperCase() + choice.slice(1).toLowerCase();
        select.appendChild(opt);
      }
    } catch (err) {
      console.error("Failed to load room seater options:", err);
      select.innerHTML =
        '<option value="" disabled selected>Unable to load options — Please check that the backend is running</option>';
    } finally {
      select.disabled = false;
    }
  }

  /* ---------------- Simple client side validation ---------------- */
  function validate(data) {
    const errors = [];

    if (!data.name.trim()) errors.push("Full name is required.");
    if (!/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(data.gmail))
      errors.push("A valid Gmail/email address is required.");
    if (!(data.year_of_birth >= 1920 && data.year_of_birth <= 2026))
      errors.push("Year of birth must be between 1920 and 2026.");
    if (!(data.month_of_birth >= 1 && data.month_of_birth <= 12))
      errors.push("Month of birth must be between 1 and 12.");
    if (!(data.day_of_birth >= 1 && data.day_of_birth <= 31))
      errors.push("Day of birth must be between 1 and 31.");
    if (!/^\d{12}$/.test(data.aadhar_number))
      errors.push("Aadhar number must be exactly 12 digits.");
    if (!/^\d{10}$/.test(data.phone_number))
      errors.push("Phone number must be exactly 10 digits.");
    if (data.address.trim().length < 5)
      errors.push("Address must be at least 5 characters long.");
    if (!data.room_seater) errors.push("Please select a room seater.");
    if (data.password.length < 8)
      errors.push("Password must be at least 8 characters.");

    return errors;
  }

  function markInvalid(el, invalid) {
    el.classList.toggle("invalid", invalid);
  }

  /* ---------------- Submit application ---------------- */
  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const data = {
      name: form.name.value,
      gmail: form.gmail.value.trim(),
      year_of_birth: parseInt(form.year_of_birth.value, 10),
      month_of_birth: parseInt(form.month_of_birth.value, 10),
      day_of_birth: parseInt(form.day_of_birth.value, 10),
      aadhar_number: form.aadhar_number.value.trim(),
      phone_number: form.phone_number.value.trim(),
      address: form.address.value.trim(),
      room_seater: form.room_seator.value,
      password: form.password.value,
    };

    markInvalid(form.gmail, !/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(data.gmail));
    markInvalid(form.year_of_birth,
      !(data.year_of_birth >= 1920 && data.year_of_birth <= 2026));
    markInvalid(form.aadhar_number, !/^\d{12}$/.test(data.aadhar_number));
    markInvalid(form.phone_number, !/^\d{10}$/.test(data.phone_number));
    markInvalid(form.password, data.password.length < 8);

    const errors = validate(data);
    showMsg(errors.join(" "), "error");
    if (errors.length > 0) return;

    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/resident-application`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });

      const body = await res.json();

      if (res.ok) {
        showMsg(`${body.message} Your application has been recorded. Welcome to Relax Space!`, "success");
        form.reset();
        select.selectedIndex = 0;
        loadRoomSeaterOptions();
      } else {
        const detail =
          typeof body.detail === "string"
            ? body.detail
            : formatValidationErrors(body.detail);
        showMsg(`Submission failed: ${detail}`, "error");
      }
    } catch (err) {
      console.error("Application submission failed:", err);
      showMsg("Something went wrong. Please check that the backend is running and try again.", "error");
    } finally {
      setLoading(false);
    }
  });

  function formatValidationErrors(detail) {
    if (!Array.isArray(detail)) return "Unknown server error.";
    return detail
      .map((e) => `${(e.loc || []).join(".")}: ${e.msg}`)
      .join(" · ");
  }

  /* ---------------- Utilities ---------------- */
  function showMsg(text, type) {
    if (!text) { msg.hidden = true; return; }
    msg.textContent = text;
    msg.className = `msg ${type}`;
    msg.hidden = false;
  }

  function setLoading(loading) {
    submitBtn.disabled = loading;
    spinner.hidden = !loading;
    btnLabel.textContent = loading ? "Submitting…" : "Submit Application";
  }

  loadRoomSeaterOptions();
});
