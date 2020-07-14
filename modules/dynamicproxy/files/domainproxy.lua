--   Copyright 2013 Yuvi Panda <yuvipanda@gmail.com>
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License.
--
-- Lua file run by nginx that does appropriate routing
-- Gets domain name, figures out instance name from it, and routes there

local redis = require 'resty.redis'
local red = redis:new()
red:set_timeout(1000)

red:connect('127.0.0.1', 6379)

local frontend = ngx.re.match(ngx.var.http_host, "^([^:]*)")[1]

local backend = red:srandmember('frontend:' .. frontend)

-- Use a connection pool of 256 connections with a 32s idle timeout
-- This also closes the current redis connection.
red:set_keepalive(1000 * 32, 256)

if backend == ngx.null then
    -- Redirect any unknown .wmflabs.org urls to .wmcloud.org
    if ngx.re.match(ngx.var.http_host, "\\.wmflabs\\.org$") then
        redirect_host = ngx.re.gsub(ngx.var.http_host, "\\.wmflabs\\.org", ".wmcloud.org")
        return ngx.redirect("https://" .. redirect_host .. ngx.var.request_uri, ngx.HTTP_MOVED_PERMANENTLY)
    end

    -- anything else, we don't know what to do with
    ngx.exit(404)
end

ngx.var.backend = backend
ngx.var.vhost = frontend
