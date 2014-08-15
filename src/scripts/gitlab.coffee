# Description:
#   Post gitlab related events using gitlab hooks
#
# Dependencies:
#   "url" : ""
#   "querystring" : ""
#
# Configuration:
#   GITLAB_CHANNEL
#   GITLAB_DEBUG
#
#   Put http://<HUBOT_URL>:<PORT>/gitlab/system as your system hook
#   Put http://<HUBOT_URL>:<PORT>/gitlab/web as your web hook (per repository)
#   You can also append "?targets=%23room1,%23room2" to the URL to control the
#   message destination.  Using the "target" parameter to override the 
#   GITLAB_CHANNEL configuration value.
#
# Commands:
#   None
#
# URLS:
#   /gitlab/system
#   /gitlab/web
#
# Author:
#   omribahumi

url = require 'url'
querystring = require 'querystring'

module.exports = (robot) ->
  gitlabChannel = process.env.GITLAB_CHANNEL or "#gitlab"
  debug = process.env.GITLAB_DEBUG?

  if robot.adapter.constructor.name is 'IrcBot'
    bold = (text) ->
      "*" + text + "*"
    underline = (text) ->
      "_" + text + "_"
  else
    bold = (text) ->
      text
    underline = (text) ->
      text

  trim_commit_url = (url) ->
    url.replace(/(\/[0-9a-f]{9})[0-9a-f]+$/, '$1')

  handler = (type, req, res) ->
    query = querystring.parse(url.parse(req.url).query)
    hook = req.body

    if debug
      console.log('query', query)
      console.log('hook', hook)

    user = {}
    user.room = if query.targets then query.targets else gitlabChannel
    user.type = query.type if query.type

    switch type
      when "system"
        switch hook.event_name
          when "project_create"
            robot.send user, "Yay! New gitlab project *#{hook.name}* created by *#{hook.owner_name}* (*#{hook.owner_email}*)"
          when "project_destroy"
            robot.send user, "Oh no! *#{hook.owner_name}* (*#{hook.owner_email}*) deleted the *#{hook.name}* project"
          when "user_add_to_team"
            robot.send user, "*#{hook.project_access}* access granted to *#{hook.user_name}* (*#{hook.user_email}*) on *#{hook.project_name}* project"
          when "user_remove_from_team"
            robot.send user, "*#{hook.project_access}* access revoked from *#{hook.user_name}* (*#{hook.user_email}*) on *#{hook.project_name}* project"
          when "user_create"
            robot.send user, "Please welcome *#{hook.name}* (*#{hook.email}*) to Gitlab!"
          when "user_destroy"
            robot.send user, "We will be missing *#{hook.name}* (*#{hook.email}*) on Gitlab"
      when "web"
        message = ""
        # is it code being pushed?
        if hook.ref
          branch = hook.ref.split("/")[2..].join("/")
          # if the ref before the commit is 00000, this is a new branch
          if /^0+$/.test(hook.before)
            message = "*#{hook.user_name}* pushed a new branch (*#{branch}*) to *#{hook.repository.name}*\n> #{hook.repository.homepage}"
          else
            message = "*#{hook.user_name}* pushed *#{hook.total_commits_count}* commits to *#{branch}* in *#{hook.repository.name}*\n> #{hook.repository.homepage + '/compare/' + hook.before.substr(0,9) + '...' + hook.after.substr(0,9)}"
          robot.send user, message
        # not code? must be a something good!
        else
          switch hook.object_kind
            when "issue"
              robot.send user, "Issue *#{hook.object_attributes.id}*: #{hook.object_attributes.title} (#{hook.object_attributes.state})"
            when "merge_request"
              robot.send user, "Merge Request *#{hook.object_attributes.id}*: #{hook.object_attributes.title} (#{hook.object_attributes.state}) between *#{hook.object_attributes.source_branch}* and *#{hook.object_attributes.target_branch}*"
          if hook.object_attributes.description
            robot.send user, ">> #{hook.object_attributes.description}"

  robot.router.post "/gitlab/system", (req, res) ->
    handler "system", req, res
    res.end ""

  robot.router.post "/gitlab/web", (req, res) ->
    handler "web", req, res
    res.end ""

