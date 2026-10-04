#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::{path::PathBuf, process::{Child, Command, Stdio}, sync::Mutex};
use tauri::Manager;

struct ApiChild(Mutex<Option<Child>>);

fn start_api() -> Option<Child> {
    let project = PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent()?.parent()?.to_path_buf();
    let python = project.join(".venv-mlx/bin/python3");
    let executable = if python.is_file() { python } else { PathBuf::from("python3") };
    Command::new(executable).args(["-m", "service.local_api"]).current_dir(project)
        .stdout(Stdio::null()).stderr(Stdio::null()).spawn().ok()
}

fn main() {
    let child = start_api();
    tauri::Builder::default()
        .manage(ApiChild(Mutex::new(child)))
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
