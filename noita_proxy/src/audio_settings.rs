use bitcode::{Decode, Encode};
use cpal::traits::{DeviceTrait, HostTrait};
use serde::{Deserialize, Serialize};

use eframe::egui::{ComboBox, Slider, Ui};

use std::collections::HashMap;

use crate::net::omni::OmniPeerId;

#[derive(Debug, Serialize, Deserialize, Decode, Encode, Clone)]
#[serde(default)]
pub struct AudioSettings {
    pub volume: HashMap<OmniPeerId, f32>,
    pub dropoff: f32,
    pub range: u64,
    //walls_strength: f32,
    //max_wall_durability: u32,
    pub player_position: bool,
    pub global: bool,
    pub push_to_talk: bool,
    pub mute_out: bool,
    pub mute_in: bool,
    pub mute_in_while_polied: bool,
    pub mute_in_while_dead: bool,
    pub disabled: bool,
    pub loopback: bool,
    pub global_output_volume: f32,
    pub global_input_volume: f32,
    pub input_device: Option<String>,
    pub output_device: Option<String>,
    pub input_devices: Vec<String>,
    pub output_devices: Vec<String>,
}

impl Default for AudioSettings {
    fn default() -> Self {
        Self {
            volume: Default::default(),
            dropoff: 1.0,
            range: 1024,
            global: false,
            //walls_strength: 1.0,
            //max_wall_durability: 14,
            player_position: true,
            push_to_talk: true,
            mute_out: false,
            mute_in: false,
            mute_in_while_polied: true,
            mute_in_while_dead: false,
            disabled: false,
            input_device: None,
            output_device: None,
            input_devices: Vec::new(),
            output_devices: Vec::new(),
            global_output_volume: 1.0,
            global_input_volume: 1.0,
            loopback: false,
        }
    }
}

impl AudioSettings {
    pub fn show_ui(&mut self, ui: &mut Ui, main: bool) -> bool {
        let mut changed = false;
        ui.label("其他玩家音量随距离衰减的速度");
        changed |= ui
            .add(Slider::new(&mut self.dropoff, 0.0..=128.0))
            .changed();
        ui.label("音频最大传播范围");
        changed |= ui.add(Slider::new(&mut self.range, 0..=4096)).changed();
        ui.label("全局输入音量");
        changed |= ui
            .add(Slider::new(&mut self.global_input_volume, 0.0..=8.0))
            .changed();
        ui.label("全局输出音量");
        changed |= ui
            .add(Slider::new(&mut self.global_output_volume, 0.0..=8.0))
            .changed();
        changed |= ui.checkbox(&mut self.loopback, "回环音频").changed();
        changed |= ui
            .checkbox(&mut self.global, "始终播放语音")
            .changed();
        changed |= ui
            .checkbox(
                &mut self.push_to_talk,
                "按键发话，按键绑定跟随 Noita，默认是 T",
            )
            .changed();
        changed |= ui
            .checkbox(
                &mut self.player_position,
                "使用玩家位置而不是摄像机位置",
            )
            .changed();
        changed |= ui.checkbox(&mut self.mute_in, "静音输入").changed();
        changed |= ui
            .checkbox(&mut self.mute_in_while_polied, "变形时静音输入")
            .changed();
        changed |= ui
            .checkbox(&mut self.mute_in_while_dead, "死亡时静音输入")
            .changed();
        changed |= ui.checkbox(&mut self.mute_out, "静音输出").changed();
        if main {
            changed |= ui.checkbox(&mut self.disabled, "禁用").changed();
            if self.input_devices.is_empty() && !self.disabled {
                #[cfg(target_os = "linux")]
                let host = cpal::available_hosts()
                    .into_iter()
                    .find(|id| *id == cpal::HostId::Jack)
                    .and_then(|id| cpal::host_from_id(id).ok())
                    .unwrap_or(cpal::default_host());
                #[cfg(not(target_os = "linux"))]
                let host = cpal::default_host();
                self.input_devices = host
                    .input_devices()
                    .map(|devices| {
                        devices
                            .filter_map(|d| d.description().map(|s| s.name().to_string()).ok())
                            .collect()
                    })
                    .unwrap_or_default();
                self.output_devices = host
                    .output_devices()
                    .map(|devices| {
                        devices
                            .filter_map(|d| d.description().map(|s| s.name().to_string()).ok())
                            .collect()
                    })
                    .unwrap_or_default();
                if self.input_device.is_none() {
                    self.input_device = host
                        .default_input_device()
                        .and_then(|a| a.description().map(|s| s.name().to_string()).ok())
                }
                if self.output_device.is_none() {
                    self.output_device = host
                        .default_output_device()
                        .and_then(|a| a.description().map(|s| s.name().to_string()).ok())
                }
            }
            ComboBox::from_label("输入设备")
                .selected_text(
                    self.input_device
                        .clone()
                        .unwrap_or_else(|| "无".to_string()),
                )
                .show_ui(ui, |ui| {
                    for device in &self.input_devices {
                        if ui
                            .selectable_label(self.input_device.as_deref() == Some(device), device)
                            .clicked()
                        {
                            self.input_device = Some(device.clone());
                            changed = true;
                        }
                    }
                });
            ComboBox::from_label("输出设备")
                .selected_text(
                    self.output_device
                        .clone()
                        .unwrap_or_else(|| "无".to_string()),
                )
                .show_ui(ui, |ui| {
                    for device in &self.output_devices {
                        if ui
                            .selectable_label(self.output_device.as_deref() == Some(device), device)
                            .clicked()
                        {
                            self.output_device = Some(device.clone());
                            changed = true;
                        }
                    }
                });
        }
        if ui.button("恢复默认").clicked() {
            *self = Default::default();
            changed = true;
        }
        changed
    }
}
