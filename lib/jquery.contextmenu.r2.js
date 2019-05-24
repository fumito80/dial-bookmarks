/*
 * ContextMenu - jQuery plugin for right-click context menus
 *
 * Author: Chris Domigan
 * Contributors: Dan G. Switzer, II
 * Parts of this plugin are inspired by Joern Zaefferer's Tooltip plugin
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Version: r2
 * Date: 16 July 2007
 *
 * For documentation visit http://www.trendskitchens.co.nz/jquery/contextmenu/
 *
 */

(function($) {

 	var menu, shadow, trigger, content, hash, currentTarget;
  var defaults = {
    menuStyle: {
      listStyle: 'none',
      padding: '1px',
      margin: '0px',
      backgroundColor: '#fff',
      border: '1px solid #999',
      "box-shadow": '2px 2px 2px #999'
    },
    itemStyle: {
      margin: '0px',
      cursor: 'default',
      padding: '3px 5px',
      border: '1px solid #fff',
      backgroundColor: 'transparent',
      "font-size": '0.9em'
    },
    itemHoverStyle: {
      backgroundColor: 'rgb(200, 220, 255)'
    },
    eventPosX: 'pageX',
    eventPosY: 'pageY',
    shadow : false,
    onContextMenu: null,
    onShowMenu: null
 	};

  $.fn.contextMenu = function(id, options) {
    if (!menu) {                                      // Create singleton menu
      menu = $('<div id="jqContextMenu"></div>')
               .hide()
               .css({position:'absolute', zIndex:'500'})
               .appendTo('body')
               .on('click', function(e) {
                 e.stopPropagation();
               });
    }
    if (!shadow) {
      shadow = $('<div id="jqContextMenuShadow"></div>')
                 .css({backgroundColor:'#000',position:'absolute',opacity:0.2,zIndex:499})
                 .appendTo('body')
                 .hide();
    }
    hash = hash || [];
    hash.push({
      id : id,
      menuStyle: $.extend({}, defaults.menuStyle, options.menuStyle || {}),
      itemStyle: $.extend({}, defaults.itemStyle, options.itemStyle || {}),
      itemHoverStyle: $.extend({}, defaults.itemHoverStyle, options.itemHoverStyle || {}),
      bindings: options.bindings || {},
      shadow: options.shadow || options.shadow === false ? options.shadow : defaults.shadow,
      onContextMenu: options.onContextMenu || defaults.onContextMenu,
      onShowMenu: options.onShowMenu || defaults.onShowMenu,
      eventPosX: options.eventPosX || defaults.eventPosX,
      eventPosY: options.eventPosY || defaults.eventPosY
    });

    var index = hash.length - 1;
    $(this).on('contextmenu', function(e) {
      // Check if onContextMenu() defined
      if ($(".selected").length > 0 || $(".opened").length==0) {
        var bShowContext = (!!hash[index].onContextMenu) ? hash[index].onContextMenu(e) : true;
        if (bShowContext) display(index, this, e, options);
      }
      return false;
    });
    return this;
  };

  function display(index, trigger, e, options) {
    //$(".folder[data-id='1'],.folder[data-id='2']").find(".delete,.editTitle").addClass("disabled")
    var dataId = e.target.parentNode.parentNode.dataset.id
    if (dataId==="1" || dataId==="2" || dataId==="3") {
      document.querySelector(".delete").className = "delete disabled";
      document.querySelector(".editTitle").className = "editTitle disabled";
    } else {
      document.querySelector(".delete").className = "delete";
      document.querySelector(".editTitle").className = "editTitle";
    }
    var cur = hash[index];
    content = $('#'+cur.id).find('ul:first').clone(true);
    if ((openModeItems$ = content.find(".openMode")).length > 0) {
      var setter, openMode, folderInfo;
      folderInfo = bmm.getFolderData(dataId);
      if (folderInfo && (openMode = folderInfo.openMode)) {
        setter = "user";
      } else {
        setter = "default";
        if (window.options.openNewTab) {
          openMode = window.options.newTabOpenType || "openLinkNewTab";
        } else {
          openMode = "openLinkCurrent"
        }
      }
      content.find("li.openMode").removeClass("user default");
      content.find("." + openMode).addClass(setter);
      // content.find("li.openMode:not(." + openMode + ")").removeClass("primary");
    }
    if (trigger.dataset.key==="xts" || trigger.dataset.key==="app") {
      if (!/disabled/.test(trigger.className) && ~~trigger.dataset.options) {
        content.find(".xtsOptions.disabled").removeClass("disabled");
      } else {
        content.find(".xtsOptions").addClass("disabled");
      }
      var disabled = "";
      if (trigger.dataset.type==="hosted_app" && !/disabled/.test(trigger.className)) {
        disabled = "disabled";
      }
      content.find(".xtsToggleEnable").text(/disabled/.test(trigger.className)? "Enable": "Disable").addClass(disabled);
    }
    content.css(cur.menuStyle).find('li').css(cur.itemStyle).filter(":not(.disabled)").hover(
      function() {
        $(this).css(cur.itemHoverStyle);
      },
      function(){
        $(this).css(cur.itemStyle);
      }
    ).find('img').css({verticalAlign:'middle',paddingRight:'2px'});

    // Send the content to the menu
    menu.html(content);

    // if there's an onShowMenu, run it now -- must run after content has been added
		// if you try to alter the content variable before the menu.html(), IE6 has issues
		// updating the content
    if (!!cur.onShowMenu) menu = cur.onShowMenu(e, menu);

    $.each(cur.bindings, function(id, func) {
      $('#'+id, menu).on('click', function(e) {
        hide();
        func(trigger, currentTarget);
      });
    });

    menu.show()
    var left = e[cur.eventPosX];
    if (menu[0].offsetWidth + left > document.body.offsetWidth) {
      left = document.body.offsetWidth - menu[0].offsetWidth - 5;
    }
    var top = e[cur.eventPosY];
    if (menu[0].offsetHeight + top > document.body.offsetHeight) {
      top -= menu[0].offsetHeight;
    }
    menu.css({'left':left,'top':top}).show();
    if (cur.shadow) shadow.css({width:menu.width(),height:menu.height(),left:left+2,top:top+2}).show();
    $(document).one('click', hide);
  }

  function hide() {
    menu.hide();
    shadow.hide();
    $(".selected").removeClass("selected");
  }

  // Apply defaults
  $.contextMenu = {
    defaults : function(userDefaults) {
      $.each(userDefaults, function(i, val) {
        if (typeof val == 'object' && defaults[i]) {
          $.extend(defaults[i], val);
        }
        else defaults[i] = val;
      });
    }
  };

})(jQuery);

$(function() {
  $('div.contextMenu').hide();
});
