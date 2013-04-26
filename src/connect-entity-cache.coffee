crypto = require "crypto"
parseURL = require("url").parse

module.exports = class ConnectEntityCache
  constructor: (options = {}) ->
    @cache = {}
    @log = options.log or (msg) ->
  
  cacheEntity: (path, headers, entity) ->
    @log "Caching #{path}"
    if headers["last-modified"]?
      lastModified = new Date headers["last-modified"]
    else
      lastModified = new Date
      headers["last-modified"] = lastModified.toUTCString()
    if headers["etag"]?
      resourceTag = headers["etag"]
    else
      resourceTag = crypto.createHash('md5').update(entity).digest("hex")
      headers["etag"] = resourceTag
    @cache[path] =
      path: path
      headers: headers
      entity: entity
      lastModified: lastModified
      eTag: resourceTag

  handle: (req, res, next) =>
    return next() unless data = @cache[parseURL(req.url).pathname]
    switch req.method
      when "OPTIONS" then handleOptions req, res, next 
      when "GET", "HEAD" then @handleProper data, req, res, next
      else @handleNonGet req, res, next
  
  handleOptions: (req, res, next) ->
    res.statusCode = 200
    res.setHeader "Allow", "OPTIONS, GET, HEAD"
    res.end ""
    
  handleProper: (data, req, res, next) ->
    if isModified data, req.headers
      res.statusCode = 200
      res.setHeader name, value for name, value of data.headers
      res.end if req.method is "GET" then data.entity else ""
    else
      res.statusCode = 304
      res.setHeader name, value for name, value of data.headers when name isnt "content-length"
      res.end ""
    @log "#{res.statusCode}: #{data.path}"

  handleNotAllowed: (req, res, next) ->
    res.statusCode = 405
    res.setHeader "Allow", "OPTIONS, GET, HEAD"
    res.setHeader "Content-Type", "text/plain"
    res.end "You can only GET this resource."
    res.end()
  
isModified = (data, headers) ->
  return true unless headers['if-modified-since']? or headers['if-none-match']?
  if headers['if-modified-since']?
    return true if data.lastModified > new Date headers['if-modified-since']
  if headers['if-none-match']?
    return true if data.eTag isnt headers['if-none-match']
  return false