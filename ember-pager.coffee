RouteMixin = Em.Mixin.create
  actions:
    loadMore: ->
      @controller.get('content').loadMore()

ControllerMixin = Em.Mixin.create
  currentPageBinding: Em.Binding.oneWay 'content.startPage'
  init: ->
    @set 'pager', Pager.create controller: this, contentBinding: 'controller.content'
    @_super()
    debounce = null
    changed = false
    currentPageChanged = => @get('content').loadPage @get 'currentPage'
    @addObserver 'currentPage', =>
      page = @get('currentPage')
      if (page != @get 'content.startPage') and (page > 0)
        # the following is a workaround for Em.run.debounce immediate not working
        if debounce
          changed = true
        else
          currentPageChanged()
          debounce = Em.run.later ->
            currentPageChanged() if changed
            debounce = null
          , 500

ScrollPaginator = Em.Object.extend
  view: null
  $scrollEl: Em.$(window)
  $el: null
  scrollBuffer: 1000
  $paddingEl: null
  checkInterval: 1000
  horizontal: false
  init: ->
    @checkInterval = 0 #debug
    @$el = @get('view').$()
    unless @$paddingEl
      @$paddingEl = Em.$('<div class="scroll-paginator-padding" />')
      @$el.prepend @$paddingEl
    @attach() if @$el
  attach: ->
    @attached = true
    @listen()
  detach: ->
    @attached = false
  debounceInterval: 500
  listen: (e)->
    if @listening then return else @listening = true
    waiting = false
    run = =>
      @loadMore() if @attached and @shouldLoadMore()
    schedule = =>
      if !waiting
        run()
        waiting = Em.run.later =>
          if runOnNext then run() 
          waiting = runOnNext = null
        , @debounceInterval
      else
        runOnNext = true
    @$scrollEl.on 'scroll', schedule
    if @checkInterval
      setInterval = =>
        Em.run.later =>
          schedule()
          setInterval() if @checkInterval
        , @checkInterval
      setInterval()
  shouldLoadMore: ->
    return if @content.get 'isFinished'
    unless @horizontal
      scrollThreshold = @$el.offset().top + @$el.height() - @scrollBuffer
      @$scrollEl.scrollTop() + @$scrollEl.height() > scrollThreshold
    else
      scrollThreshold = @$el.offset().left + @$el.width() - @scrollBuffer
      @$scrollEl.scrollLeft() + @$scrollEl.width() > scrollThreshold
  loadMore: ->
    @content.loadMore()

ScrollPaginatorMixin = Em.Mixin.create
  didInsertElement: ->
    @_super()
    @scrollHelper = ScrollPaginator.create
      content: @get 'controller.content'
      view: this
  willDestroyElement: ->
    @_super()
    @scrollHelper.detach()

handlePageBounds = (property)->
  (->
    page = @get "content.#{property}"
    lastPage = @get 'lastPage'
    if page > lastPage then page = lastPage
    if page < 1 then page = 1
    page
  ).property "content.#{property}", 'lastPage'

Pager = Em.ObjectProxy.extend
  content: null
  lastPage: (->
    Math.ceil @get('total') / @get('pageSize')
  ).property 'pageSize', 'total'
  startPage: handlePageBounds 'startPage'
  endPage: handlePageBounds 'endPage'
  start: (->
    (@get('startPage') - 1) * @get('pageSize') + 1
  ).property 'startPage', 'pageSize'
  end: (->
    total = @get('total')
    end = @get('endPage') * @get('pageSize')
    if total != undefined and end > total
      end = total
    end
  ).property 'endPage', 'pageSize'

module = 
  RouteMixin: RouteMixin
  ControllerMixin: ControllerMixin
  ScrollPaginator: ScrollPaginator
  ScrollPaginatorMixin: ScrollPaginatorMixin

# ES6: `export default module`
# Current workaround:
Ember.Pager = module
