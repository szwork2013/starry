# 故事 Api
async = require 'async'
validator = require 'validator'
router = require('express').Router()

Story = require '../models/story'
Section = require '../models/section'

# 权限过滤
router.route('/*').get (req, res, done) ->
  if not req.user
    return res.status(401).json
      error: '未登录，没有此权限'
  done()

# 新建
router.route('/').post (req, res, done) ->
  async.waterfall [
    (fn) ->
      section = new Section name: ''
      section.save (err, section) -> fn err, section
    (section, fn) ->
      story = new Story
        author: req.user.id
        sections: [ section.id ]

      story.save (err, story) -> fn err, story
  ], (err, story) ->
    return done err if err
    res.status(201).json id: story.id

# 删除故事
router.route(/^\/([0-9a-fA-F]{24})$/).delete (req, res, done) ->
  async.waterfall [
    (fn) ->
      Story.findById req.params[0], 'title', fn
    (story, fn) ->
      story.remove (err) -> fn err, story
  ], (err, story) ->
    return done err if err
    res.status(202).json id: story.id

# 更新故事
router.route(/^\/([0-9a-fA-F]{24})$/).patch (req, res, done) ->
  {background, cover, theme} = req.body

  req.assert('background', '背景地址格式不正确').isURL() if background
  req.assert('cover', '封面地址格式不正确').isURL() if cover
  req.assert('theme', '主题格式不正确').isAlpha() if theme

  errs = req.validationErrors()
  return done isValidation: true, errors: errs if errs

  async.waterfall [
    (fn) ->
      Story.findById req.params[0], 'background cover theme', fn
    (story, fn) ->
      story.background = background if background
      story.cover = cover if cover
      story.theme = theme if theme
      story.save (err) -> fn err, story
  ], (err, story) ->
    return done err if err
    res.status(202).json story

# 更新故事简介
router.route(/^\/([0-9a-fA-F]{24})$/).post (req, res, done) ->
  req.assert('title', '标题不能为空').notEmpty()
  req.assert('mark', '标识不能为空').notEmpty()
  req.assert('mark', '标识格式不正确').matches /^[a-zA-Z0-9\-\.]+$/

  errs = req.validationErrors()
  return done isValidation: true, errors: errs if errs
  done()
.post (req, res, done) ->
  mark = req.body.mark.trim()
  Story.count { mark: mark, _id: $ne: req.params[0] }, (err, count) ->
    if 0 < count
      return done isValidation: true, errors: [
        param: 'mark'
        msg: '该标识已经被使用'
        value: mark
      ]
    done()
.post (req, res, done) ->
  async.waterfall [
    (fn) ->
      Story.findById req.params[0], 'title description mark', fn
    (story, fn) ->
      story.title = req.sanitize('title').escape()
      story.description = req.sanitize('description').escape()
      story.mark = req.body.mark.trim()
      story.save (err) -> fn err, story
  ], (err, story) ->
    return done err if err
    res.status(202).json story

# 列表
router.route('/').get (req, res) ->
  Story.find { author: req.user.id }, 'title cover', { sort: id: -1 }, (err, stories) ->
    return done err if err
    res.status(200).json stories

# 详情
router.route(/^\/([0-9a-fA-F]{24})$/).get (req, res) ->
  Story.findById req.params[0], 'title description mark background cover theme sections'
  .populate path: 'sections', select: 'name points'
  .exec (err, story) ->
    return done err if err
    res.status(200).json story

module.exports = router
