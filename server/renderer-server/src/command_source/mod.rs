/**
 * @license
 * This file is part of Hacklily, a web-based LilyPond editor.
 * Copyright (C) 2018 - present Jocelyn Stericker <jocelyn@nettek.ca>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
use std::future::Future;
use std::pin::Pin;
use tokio::sync::mpsc::Sender;
use tokio_stream::Stream;

use crate::config::{CommandSourceConfig, Config};
use crate::error::HacklilyError;
use crate::request::{Request, Response};

mod batch;
mod test_runner;
mod ws_worker_client;

use self::batch::batch;
use self::test_runner::test_runner;
use self::ws_worker_client::ws_worker_client;

#[derive(Debug)]
pub struct QuitSignal {}

pub type ResponseCallback = Box<dyn Fn(Response) + Send + 'static>;
pub type QuitSink = Sender<QuitSignal>;

pub type RequestStream = Box<
    dyn Stream<Item = Result<(Request, ResponseCallback), HacklilyError>> + Send + Unpin + 'static,
>;

pub type FutureCommandSource =
    Pin<Box<dyn Future<Output = Result<(RequestStream, QuitSink), HacklilyError>> + Send>>;

pub fn new(config: &Config) -> FutureCommandSource {
    match &config.command_source {
        CommandSourceConfig::Worker { coordinator } => {
            let worker_count = config.stable_worker_count + config.unstable_worker_count;
            Box::pin(ws_worker_client(coordinator.clone(), worker_count))
        }
        CommandSourceConfig::Batch { path } => Box::pin(batch(path.clone())),
        CommandSourceConfig::TestRunner { input, output } => {
            Box::pin(test_runner(input.clone(), output.clone()))
        }
    }
}
