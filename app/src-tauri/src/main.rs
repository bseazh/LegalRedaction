#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::{path::PathBuf, process::{Child, Command, Stdio}, sync::Mutex};
use tauri::Manager;

struct ApiChild(Mutex<Option<Child>>);

fn start_api(app: &tauri::AppHandle) -> Option<Child> {
    let project = PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent()?.parent()?.to_path_buf();
    let (executable, args, work_dir, model_dir) = if cfg!(debug_assertions) {
        (project.join(".venv-mlx/bin/python3"), vec!["-m", "service.local_api"], project.clone(), project.join("models/qwen3/Qwen3-1.7B-bf16"))
    } else {
        let resources = app.path().resource_dir().ok()?;
        (resources.join("sidecar/legalredaction-service/legalredaction-service"), vec![], resources.clone(), resources.join("models/qwen3/Qwen3-1.7B-bf16"))
    };
    let log_dir = app.path().app_log_dir().ok()?;
    let _ = std::fs::create_dir_all(&log_dir);
    Command::new(executable).args(args).current_dir(work_dir)
        .env("LEGALREDACTION_MODEL_DIR", model_dir)
        .env("LEGALREDACTION_LOG_DIR", log_dir)
        .stdout(Stdio::null()).stderr(Stdio::null()).spawn().ok()
}

fn main() {
    tauri::Builder::default()
        .manage(ApiChild(Mutex::new(None)))
        .setup(|app| {
            let child = start_api(app.handle());
            if let Ok(mut state) = app.state::<ApiChild>().0.lock() { *state = child; }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building LegalRedaction")
        .run(|app, event| {
            if let tauri::RunEvent::Exit = event {
                if let Some(state) = app.try_state::<ApiChild>() {
                    if let Ok(mut child) = state.0.lock() { if let Some(mut process) = child.take() { let _ = process.kill(); } }
                }
            }
        });
}
