use log::debug;
use regex::Regex;

use super::FingerPrint;
use crate::config::Config;
use crate::insights_operator_runtime::ContainerProcess;

pub struct VersionExecutable {}

impl FingerPrint for VersionExecutable {
    fn can_apply_to(&self, config: &Config, process: &ContainerProcess) -> Option<Vec<String>> {
        debug!(
            "Checking if {:#?} is an executable with that has a `--version`",
            { &process.name }
        );

        let fpr_kind_executable = String::from("./fpr_kind_executable");
        let fpr_runtime_executable = String::from("./fpr_runtime_executable");
        let outdir = format!("out/{}", process.pid);

        if let Some(version_executable) =
            config.fingerprints.versioned_executables.iter().find(|c| {
                let re = Regex::new(&c.process_command).unwrap();
                re.is_match(&process.command_line[0])
            })
        {
            return Some(vec![
                fpr_kind_executable,
                String::from(&process.command_line[0]),
                String::from(&version_executable.runtime_kind_name),
                outdir,
            ]);
        }

        None
    }
}

pub fn is_version_executable(process: &ContainerProcess) -> bool {
    let proc_name = &process.name;
    let proc_cmd = &process.command_line[0];

    proc_name.ends_with("node")
        || proc_name.ends_with("postgres")
        || proc_cmd.contains("python")
        || proc_cmd.contains("mysqld")
        || proc_cmd.contains("java")
}
