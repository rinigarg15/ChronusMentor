// To be called explicitly inside views when the GET is ajax,
// otherwise will be called when the page loads
var initialize = {
  animateWrapper: function()
  {
    jQuery(".wrapper.wrapper-content").hide().show("fade", { direction: "right" }, 1000);
    jQuery("#sidebarLeft").removeClass("hide");
    jQuery("#page_loading_results").addClass("hide");
  },

  initializeMatchDetailsPopup: function(){
    jQuery(document).on("click", ".cjs_show_match_details", function(){
      initialize.ShowMatchDetailsPopup(jQuery(this));
    });
  },

  initializeMatchDetailsPopupFor: function(selector){
    jQuery(selector).on('click', function(){
      initialize.ShowMatchDetailsPopup(jQuery(this));
    });
  },

  ShowMatchDetailsPopup: function(element){
    var url = element.data("url");
    jQueryShowQtip('#inner_content', 675, url, '', {modal: true});
  },

  initializePlaceholder: function() {
    // Doing this for IE9 to avoid slowing down on other browsers
    if (navigator.userAgent.match(/MSIE 9/)) {
      jQuery('input, textarea').each(function(){
        if (!jQuery(this).closest('.uninitplaceholder').length)
          jQuery(this).placeholder();
      });
    }
  },

  initializeProgramHeaderTile: function() {
    jQuery(document).ready(function() {
      handleProgramNameHeaderWidth();
    });
    jQuery(window).on("resize", function () {
      resetClassesForProgramNameHeader();
      handleProgramNameHeaderWidth();
    });
  },

  fixIOSkeypadHeaderPosition: function() {
    if (navigator.userAgent.toLowerCase().match(/iphone|ipod|ipad/)) {
      /* bind events */
      jQuery(document)
      .on('focus', 'input:not(:checkbox, :radio), textarea, select', function(e) {
          jQuery(".navbar-fixed-top").css({"position": "absolute", "top": "-" + jQuery('.navbar-fixed-top').outerHeight().toString() + "px"});
      })
      .on('blur', 'input:not(:checkbox, :radio), textarea, select', function(e) {
          jQuery(".navbar-fixed-top").css({"position": "fixed", "top": "0"});
      });
    }
  },

  fixAndroidFooterPosition: function() {
    if (navigator.userAgent.toLowerCase().match(/chronusandroid/)) {
      jQuery(document)
      .on('focus', 'input:not(:checkbox, :radio), textarea, select', function(e) {
          jQuery(".cui-affixed-footer").css({"position": "absolute"});
      }).on('blur', 'input:not(:checkbox, :radio), textarea, select', function(e) {
          jQuery(".cui-affixed-footer").css({"position": "fixed", "bottom": "0"});
      });
    }
  },

  initializeWrapperVisibility: function() {
    jQuery(document).on('show.bs.modal', '.modal', function (e) {
      if(jQuery(this).hasClass('cui-non-full-page-modal'))
        jQuery('#wrapper').show();
      else
        jQuery('#wrapper').css('display', "");
    });
  },

  /* Scroll to a +scroll_to+ div */
  /* The scrolling happen if the url has the option +scroll_to+ */
  scrollToFromParams: function()
  {
    var scroll_to_param = jQueryReadUrlParam('scroll_to');
    if(scroll_to_param){
      jQueryScrollTo('#'+ scroll_to_param, true)
    }
  },

  disableNavTabClick: function() {
    jQuery(document).ready(function() {
      jQuery(".nav li.disabled a").click(function() {
      return false;
    });
  });
  },

  dismissableAlert: function() {
    jQuery(document).on('click', ".alert .close", function(){
      var dataurl = jQuery(this).attr('data-url');
      if(dataurl){
        jQuery.ajax({
          url: dataurl
        });
      }
    });
  },

  jQueryAutoComplete: function()
  {
    jQuery('.clientSideAutoComplete').each(function(ind, ele){
      options = jQuery(ele).attr('autoCompleteOptions').split(',');
      jQuery(ele).autocomplete({
        source: options,
        appendTo: jQuery(ele).closest("form")

      });


    });

    //Attach jquery_complete class to the input element.
    //Autocomplete method expects 3 characters to be entered in the text field.
    jQuery("input.jquery_server_autocomplete").each(function(){
      var inputObj = jQuery(this);
      var loader = jQuery("#" + inputObj.data("indicator"));
      inputObj.autocomplete({
        minLength: 3,
        search: function(){
          if(loader.length > 0){
            loader.show();
          }
        },
        source: function(request, response){
          jQuery.ajax({
            url: inputObj.data("autocomplete-url"),
            dataType: "json",
            data: {
              "search" : request.term
            },
            success: response,
            complete: function(){
              if(loader.length > 0){
                loader.hide();
              }
            }
          });
        }
      });
    });
    jQuery("input.jquery_server_autocomplete_for_meeting").each(function(){
      var inputObj = jQuery(this);
      var loader = jQuery("#" + inputObj.data("indicator"));
      inputObj.autocomplete({
        minLength: 1,
        appendTo: "#auto_result_holder",
        search: function(){
          if(loader.length > 0){
            loader.show();
          }
        },
        select: function (event, ui) {
          var v = ui.item.value;
          jQuery(".cjs_auto_complete_meeting_attendee_ids").val(jQuery(v).data('userid'));
          jQuery("#student_name_auto_complete_for_meeting").val(jQuery(v).html());
          return false;
        },
        source: function(request, response){
        jQuery.ajax({
          url: inputObj.data("autocomplete-url"),
          dataType: "json",
          data: {
          "search" : request.term
          },
          success: response,
          complete: function(){
          if(loader.length > 0){
          loader.hide();
          }
          }
          });
        }
        }).data( "autocomplete" )._renderItem = function( ul, item ) {
        return jQuery( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>"+ item.label + "</a>" )
        .appendTo( ul );
      };
    });
  },
  navigationChecker: function()
  {
    // The jQuery below sets the windowUnloadAlert function when there is something to be saved when a user tries to navigate away from the page with the textfield/textarea filled
    //The navigation_checker class can be added to any textfield/textarea which needs this kind of a valiadation
    //Optional Attributes can be passed - navigation_default_value, which will be the default text supplied to the textfield/textarea
    jQuery('.navigation_checker').change(function (event)
    {
      if (jQuery(this).attr('navigation_default_value'))
      {
        if (jQuery(this).val() != jQuery(this).attr('navigation_default_value') )
          windowUnloadAlert.setAlert(this);
      }
      else
        windowUnloadAlert.setAlert(this);
    });
  },
  autoResizeTextAreas: function()
  {
    autosize(jQuery('textarea:not(.no_autosize)'));
  },
  dropDownButton: function()
  {
    //This for the dropdown button
    var dropDownButtons = jQuery('a.dpdown')
    var dropDownMenu = dropDownButtons.parent().children('span')

    jQuery('html').live('click',function() {
      dropDownMenu.hide();
    });

    dropDownButtons.live('click',function (event){
      jQuery(this).parent().children('span').toggle();
      event.stopPropagation();
    });

    dropDownMenu.live('click',function (event){
      jQuery(this).hide();
    });
  },
  tagList: function()
  {
    jQuery.each(jQuery(".tag_list_input"), function (index, ele){
      taglist = (typeof(jQuery(ele).attr('input_tags')) == 'undefined') ? [] : jQuery(ele).attr('input_tags').split(',')
      jQuery(ele).select2({
        tags: taglist,
        tokenSeparators: [','],
        placeholder: function(){
          jQuery(ele).data('placeholder');
        },
        formatResult: function(result, container){
          removeFastClickForSelect2(container);
          return result.text;
        }
      });
      GroupUpdate.bindAccessibilityAttributes(jQuery(ele).parent().attr("id"));
    });
  },

  displayOnHover: function(argument) {
    jQuery('.cjs_hover_toggle').live('mouseover', function(){
      jQuery(this).find("."+ jQuery(this).data("hover-class")).show();
    }).live('mouseout', function(){
      jQuery(this).find("."+jQuery(this).data("hover-class")).hide();
    });
  },

  columnize: function(){
    jQuery("ul.columnize").makeacolumnlists();
  },

  showOnScroll: function(){
    jQuery('.showOnScroll').scrollelement({
      offset: 10
    });
  },

  sortableTabs: function(){
    jQuery( ".jquery_tabs" ).tabs().find(".ui-tabs-nav.sort").sortable({
      axis: "x",
      update: function (event, ui) {
        var newSortOrder = []
        jQuery(this).find('li a').each(function(i,a){
          newSortOrder.push(jQuery(a).data('id'))
        })
        jQuery.ajax({
          url : jQuery(this).data("url"),
          type: jQuery(this).data("method"),
          data: {
            new_order: newSortOrder
          }
        });
      }
    });
  },

  editPageTitle: function(){
    jQuery(".edit_page_title").bind('click', function(){
      jQueryShowQtip("#inner_content", 585, jQuery(this).data("url"),"", {
        modal: true
      });
      return false;
    });
  },

  renderOmbeded: function(){
    jQuery.each(jQuery(".cjs_embedded_media"), function(index, ele){
      jQuery(ele).oembed(jQuery(ele).text());
    });
  },

  tabDropdowns: function(){
    jQuery("#tab_box #tabs.nav li.dropdown").mouseenter(function(){
      jQuery(this).children(".dropdown-menu").show();
    }).mouseleave(function(){
      jQuery(this).children(".dropdown-menu").hide();
    });
  },

  popupCloseBox: function() {
    jQuery(".popup_closebox btn-white").live('click', function(){
      hideQtip();
    })
  },

  initializeQtipOnHover: function(posOption){
    jQuery(".cjs_qtip_on_hover").each(function(){
      var topPos = {
        my: 'bottom center',
        at: 'top center',
        target: jQuery(this)
      };
      var botPos = {
        my: 'top center',
        at: 'bottom center',
        target: jQuery(this)
      };
      var rightPos = {
        my: 'left center',
        at: 'right center',
        target: jQuery(this)
      };
      var pos = {};

      if (typeof posOption == 'undefined')
        pos = topPos;
      else if (posOption == 'top')
        pos = topPos;
      else if (posOption == 'bottom')
        pos = botPos;
      else if (posOption == 'right')
        pos = rightPos;

      jQuery(this).qtip({
        content: jQuery(this).data('desc'),
        position: pos
      });
    });
  },

  increaseHeightonScroll: function(){
    if(jQuery("#two_column_container #side_column").length > 0){
      if (jQuery.browser.msie && parseInt(jQuery.browser.version)< 10){
        jQuery("#two_column_container #side_column").css("background","url('/assets/v3/layout/secnd_col_bg.png') repeat-y scroll 0 0 #F5F5F5");
        correctSideHeightifRequired();

        jQuery(window).scroll(function(){
          correctSideHeightifRequired();
        });
      }
    }
  },

  initializeTooltip: function(){
    jQuery('.tooltip').remove();
    jQuery('.cjs-tool-tip').each(function(){
      var placement = jQuery(this).data('placement') || 'top';
      jQuery(this).tooltip({
        title: jQuery(this).data('desc'),
        html: true,
        placement: placement,
        container: "body"
      });
    });

    // initialize a tooltip with a text given in the attribute 'title'
    jQuery("[rel='tooltip']").tooltip({placement: 'top'});
  },

  initializeStopFilterPropogation: function(){
    jQuery(document).on("click", function(e) {
      jQuery("#dropdown_filter_dummy_element").remove();
    });
    jQuery(".dropdown_button_container").on("click", function(e) {
      if(jQuery(".dropdown_button_container").hasClass("open")){
        jQuery("#dropdown_filter_dummy_element").remove();
      }
      else{
        DropdownFilter.setPageHeight();
      }
    });
    jQuery('.dropdown-menu li .accordion').on("click", function(e) {
      e.stopPropagation();
      setTimeout(function(){
        DropdownFilter.setPageHeight();
      },500);
    });
  },

  initializeBlindHide: function(){
    jQuery(".blind-hide-icon").on('click', function(event){
      event.preventDefault();
      jQueryBlind(jQuery(".blind-hide-icon").closest('.blind-hide-notice'));
    });
  },

  // Used for truncation by rows and by text
  // Arrangement should be:
  // part of content + show link in one container and right after this container with whole content + hide link
  initializeMoreLessLinks: function(){
    // Text
    jQuery(document).on("click", ".cjs_see_more_link", function(e){
      jQuery(this).parent().hide();
      jQuery(this).parent().next().show();
      if(jQuery(this).hasClass('cjs_stop_propagation')){
        e.stopPropagation();
      }
    });

    jQuery(document).on("click", ".cjs_see_less_link", function(e){
      jQuery(this).parent().hide();
      jQuery(this).parent().prev().show();
      if(jQuery(this).hasClass('cjs_stop_propagation')){
        e.stopPropagation();
      }
    });
    // Rows
    jQuery(document).on("click", ".cjs_see_more_rows_link", function(){
      jQuery(this).hide();
      jQuery(this).parent().next().show();
    });

    jQuery(document).on("click", ".cjs_see_less_rows_link", function(){
      jQuery(this).parent().hide();
      jQuery(this).parent().prev().find('.cjs_see_more_rows_link').show();
    });
    // Table
    jQuery(document).on("click", ".cjs_see_more_tr_link", function(){
      var group_id = jQuery(this).data("group-id");
      jQuery('#group_activity_details_' + group_id).find('.follow_ajax_loader').show();
    });

    jQuery(document).on("click", ".cjs_see_less_tr_link", function(){
      var group_id = jQuery(this).data("group-id");
      jQuery(this).hide();
      jQuery(this).prev().show();
      jQuery('#group_activity_details_' + group_id).find('tr.collapsable').hide();
    });
  },


  initializeHoverCard: function(){
    jQuery(document).on({
      mouseover: function(e){
        if(!jQuery(e.target).hasClass("cjs-onhover-text")){
          HoverCard.showHoverCard(jQuery(this), jQuery(this).data('user-id'));
        }
      }}, ".cjs-user-link-container");
    jQuery(document).on({
      mouseover: function(){
        jQuery(this).addClass("on-hover");
      }}, ".cjs-hovercard-container");
    jQuery(document).on({
      mouseleave: function(){
        HoverCard.revertHoverCardTimeOuts();
        HoverCard.hideHoverCard(jQuery(this));
      }}, ".cjs-hovercard-container, .cjs-user-link-container");
  },

  //Fix for the attachement issue - https://github.com/galetahub/ckeditor/issues/79
  //Note: We no longer use ckeditor attachment
  fixCkeditorAttachmentLinks: function(){
    jQuery(document).on("click", "a[_cke_saved_href]", function(){
      var url = jQuery(this).attr("_cke_saved_href");
      url = url.replace(/http:\/\/http/g, "http");
      jQuery(this).attr("href", url);
      jQuery(this).attr("target", "_blank");
      jQuery(this).addClass("cjs_external_link");
    });
  },

  initializeCkAttachmentLinksForAndroid: function (){
    jQuery("a[href*='ck_attachments']").addClass("cjs_android_download_ckeditor_files");
  },

  setModalWidth: function(width){
    var marginLeft = parseInt(jQuery(".modal").css("margin-left"));
    var currentWidth = jQuery(".modal").width();
    marginLeft = marginLeft + ((currentWidth-width)/2);
    jQuery(".modal").css({"width": width, "margin-left": marginLeft.toString()+"px"});
  },

  colorPicker: function(){
    jQuery('.colorpicker').minicolors({animationSpeed: 50,
        animationEasing: 'swing',
        change: null,
        changeDelay: 0,
        control: 'hue',
        dataUris: true,
        defaultValue: '',
        format: 'hex',
        hide: null,
        hideSpeed: 100,
        inline: false,
        keywords: '',
        letterCase: 'lowercase',
        opacity: false,
        position: 'bottom left',
        show: null,
        showSpeed: 100,
        theme: 'bootstrap'});
  },

  initializePagination: function(){
    var paginationLinks = "ul.pagination.ajax_pagination a";
      jQuery(document).on('click', paginationLinks, function(event){
        event.preventDefault();
        jQuery.ajax({
          url: jQuery(this).attr("href"),
          data: jQuery.param({format: 'js'}),
          beforeSend: function(){
            jQuery("#loading_results").show();
          },
          complete: function(){
            jQueryResetPageTop();
          }
        });
      });
  },

  initializeFileinput: function(){
    jQuery("input[type='file']:not(.quick_file):not(.cui-fileinput-initialized, .cjs-dropzone)").each(function(){

      jQuery("label[for=" + jQuery(this).attr("id") + "]").each(function(){
        if(!jQuery(this).closest('.group-span-filestyle').length > 0)
          jQuery(this).attr("for", "");
      })

      jQuery(this).addClass('cui-fileinput-initialized').filestyle({
        iconName: "fa fa-paperclip fa-fw",
        buttonName : 'needsclick no-waves btn-white noshadow no-margins',
        buttonText : jQuery(this).closest('.cjs-attachment').hasClass('cui_no_browse_text') ? "" : fileInputTranslations.browse,
        removeButtonText: jQuery(this).closest('.cjs-attachment').hasClass('cui_no_browse_text') ? "" : fileInputTranslations.remove,
        labelText: fileInputTranslations.attach_a_file,
        placeholder: fileInputTranslations.click_to_attach
      });
    })

    jQuery("input[type='file'].quick_file:not(.cui-fileinput-initialized, .cjs-dropzone)").each(function(){

      jQuery("label[for=" + jQuery(this).attr("id") + "]").each(function(){
        if(!jQuery(this).closest('.group-span-filestyle').length > 0)
          jQuery(this).attr("for", "");
      })

      jQuery(this).addClass('cui-fileinput-initialized').filestyle({
        input: false,
        iconName: "fa fa-paperclip fa-fw",
        buttonName : 'needsclick no-waves btn-white noshadow no-margins',
        buttonText : jQuery(this).closest('.cjs-attachment').hasClass('cui_no_browse_text') ? "" : fileInputTranslations.browse,
        removeButtonText: jQuery(this).closest('.cjs-attachment').hasClass('cui_no_browse_text') ? "" : fileInputTranslations.remove,
        size: jQuery(this).data("size"),
        labelText: fileInputTranslations.attach_a_file,
        removeButtonClass: jQuery(this).data("remove-button-class")
      });
    })
    DropzoneConfig.initializeDropzone();
  },

  initializeWaves: function(){
    if (navigator.userAgent.match(/MSIE 9/) == null) {
      if(typeof(Waves) !== 'undefined'){
        Waves.attach('.nav:not(.nav-tabs) a:not(.no-waves), .dropdown-menu a, .btn:not([data-replace-content]):not([data-disable-with]):not(input):not(.btn-icon):not(.btn-float):not(.btn-file):not(.no-waves)');
        Waves.attach('.btn-icon, .btn-float', ['waves-circle', 'waves-float']);
        Waves.init();
      }
    }
  },

  initializeToggleButton: function(){
    jQuery(document).on("click", "a[data-replace-content]", function(){
      var element = jQuery(this);
      var requestUrl = element.data("url");
      var requestType = element.data("method");
      var currentContent = element.html();
      var replaceContent = element.data("replace-content");
      var toggleClass = element.data("toggle-class");

      jQuery.ajax({
        url: requestUrl,
        type: requestType,
        beforeSend: function(){
          element.attr("disabled", "disabled");
        },
        success: function(){
          element.attr("disabled", false);
          if(toggleClass)
            element.toggleClass(toggleClass);
          element.data("replace-content", currentContent);
          element.removeClass("waves-effect");
          element.html(replaceContent);
        }
      });
    });
  },

  setSlimScroll: function(){
    jQuery("[data-slim-scroll=true]").each(function(){
      height = jQuery(this).data("slim-scroll-height");
      if(height === undefined)
        height = "200";
      visible = jQuery(this).data("slim-scroll-visible");
      if(visible === undefined)
        visible = true;
      jQuery(this).slimScroll({
        height: height + 'px',
        alwaysVisible: visible,
        railVisible: visible
      });
    });
  },

  setDatePicker: function(){
    jQuery("[data-date-picker=true]:not(.cjs-date-picker-added)").each(function(){
      var minDate = jQuery(this).data("min-date");
      var maxDate = jQuery(this).data("max-date");
      var disableDatePicker = jQuery(this).data("disable-date-picker");
      var dateRange = jQuery(this).data("date-range");
      var wrapperClass = jQuery(this).data("wrapper-class") || "";
      var randId = jQuery(this).data("rand-id");
      var initialInputClasses = jQuery(this).attr("class");
      var datePickerOptions = {};

      datePickerOptions.format = datePickerTranslations.fullDateFormat;
      if(minDate)
        datePickerOptions.min = new Date(minDate);
      if(maxDate)
        datePickerOptions.max = new Date(maxDate);
      if(dateRange == "start"){
        datePickerOptions.change = function() {
          DateRangePicker.updateDatePickerEnd(this);
          DateRangePicker.updateHiddenField(this);
        }
      }else if(dateRange == "end"){
        datePickerOptions.change = function() {
          DateRangePicker.updateDatePickerStart(this);
          DateRangePicker.updateHiddenField(this);
        }
      }

      if(!jQuery(this).hasClass("cjs_no_clear_selection")){
        datePickerOptions.open = function(e){
          var footer = this.dateView.calendar.wrapper.find(".k-footer");
          if(!footer.find(".cjs_datepicker_clear_selection").length){
            var clearSelectionLabel = "<i class='fa fa-undo m-r-xs'></i>" + datePickerTranslations.clearSelection;
            var clearSelectionContent = "<a href='javascript:void(0)' class='cjs_datepicker_clear_selection k-link' data-rand-id=" + randId + ">" + clearSelectionLabel + "</a>";
            footer.append(clearSelectionContent);
          }
          if(this.value()){
            footer.find(".cjs_datepicker_clear_selection").show();
          }else{
            footer.find(".cjs_datepicker_clear_selection").hide();
          }
        }
      }

      jQuery(this).kendoDatePicker(datePickerOptions);
      var datePicker = jQuery(this).data("kendoDatePicker");
      if(disableDatePicker)
        datePicker.enable(false);
      else
        datePicker.readonly();

      // kendoDatePicker adds the classes in input to the wrapper - removing them
      // 'cjs-date-picker-added' - prevents multiple initialization
      // 'cui-date-picker-added' - styling-scope-class for the date-picker - to prevent the kendoGrid datepickers from using these styles
      datePicker.wrapper.removeClass(initialInputClasses);
      datePicker.wrapper.addClass("form-control");
      datePicker.wrapper.addClass(wrapperClass);
      datePicker.wrapper.addClass("cui-date-picker-added");
      datePicker.element.addClass("cjs-date-picker-added");
    });
  },

  CheckBoxStopPropagation: function() {
    jQuery(document).on("click", ".checkbox.checkbox-primary", function(event){
      event.stopPropagation();
    });
  },

  initializeDatePicker: function(){
    jQuery(document).on("click", ".cjs-date-picker-added[data-date-picker=true]", function(){
      var datePicker = jQuery(this).data("kendoDatePicker");
      datePicker.open();

      //ADA Compliance. The below values can be accessed only after the calendar is 'opened'.
      var prevArrow = datePicker.dateView.calendar._prevArrow;
      var nextArrow = datePicker.dateView.calendar._nextArrow;
      if(!prevArrow.text()){
        addAccessibilityContentToEmptyLinks(prevArrow, datePickerTranslations.prevText);
        addAccessibilityContentToEmptyLinks(nextArrow, datePickerTranslations.nextText);
      }
    });

    jQuery(document).on("click", ".cjs_datepicker_clear_selection", function(){
      var randId = jQuery(this).data("rand-id");
      var datePicker = jQuery(".cjs-date-picker-added[data-rand-id=" + randId + "]").data("kendoDatePicker");
      datePicker.value(null);
      datePicker.trigger('change');
      datePicker.close();
    });
  },

  initializeDateRangePicker: function(){
    jQuery(document).on("change", DateRangePicker.presetSelect, function(){
      var wrapper = jQuery(this).closest(DateRangePicker.wrapper);
      var startDatePickerElement = wrapper.find(DateRangePicker.startInput);
      var endDatePickerElement = wrapper.find(DateRangePicker.endInput);
      var startDatePicker = startDatePickerElement.data("kendoDatePicker");
      var endDatePicker = endDatePickerElement.data("kendoDatePicker");
      var programStartDate = jQuery(this).data("program-start-date");
      var selectedPreset = jQuery(this).val();
      var currentDate = jQuery(this).data("current-date");

      if(selectedPreset == "custom"){
        startDatePicker.enable();
        endDatePicker.enable();
        startDatePicker.readonly();
        endDatePicker.readonly();
        DateRangePicker.updateHiddenField(startDatePicker);
      }
      else{
        DateRangePicker.setStartAndEndDate(selectedPreset, wrapper, programStartDate, currentDate);
        startDatePicker.enable(false);
        endDatePicker.enable(false);
      }
    });
  },

  reInitializeDateRangePicker: function(dateRangePicker){
    var dateRangePickerElements = dateRangePicker.find(".cjs-date-picker-added");
    dateRangePickerElements.removeClass("cjs-date-picker-added");
    DateRangePicker.makeWCAGChangesForDateRangePicker(dateRangePicker);
    AdminViewsNewView.initializeDatePicker();
    jQuery.each(dateRangePicker.find(".cjs_daterange_picker_value"), function(index, element){
      DateRangePicker.clearInputs(element);
    });
  },

  reInitializeDatePicker: function(datePicker){
    datePicker.removeClass("cjs-date-picker-added");
    var randId = generateRandomIdForDatepicker();
    datePicker.attr("data-rand-id", "datepicker-" + randId);
    datePicker.data("rand-id", "datepicker-" + randId);
    datePicker.data("min-date", "");
    datePicker.data("max-date", "");
    initialize.setDatePicker();
    initialize.initializeDatePicker();
  },

  toggleCollapseIcon: function(){
    jQuery(document).on("click", "[data-toggle=collapse]", function(){
      jQuery(this).find(".cjs_collapse_icon").toggleClass('fa-chevron-down fa-chevron-up');
    });
  },

  initializeAjaxLinks: function() {
    jQuery(document).on("click", "[data-ajax-url]", function() {
      var hideLoader = jQuery(this).data("ajax-hide-loader");

      jQuery.ajax({
        url: jQuery(this).data("ajax-url"),
        method: jQuery(this).data("ajax-method") || "get",
        beforeSend: function() {
          if(!hideLoader) {
            jQuery("#loading_results").show();
          }
        },
        complete: function() {
          jQuery("#loading_results").hide();
        }
      });
    });
  },

  initializeLinksToRemoteModal: function() {
    jQuery(document).on("click", "[data-remote-modal-url]", function() {
      jQueryShowQtip(null, null, jQuery(this).data("remote-modal-url"), {}, {});
    });
  },

  addListenerToSignout: function() {
    jQuery(document).on("click", ".cjs_signout_link", function() {
      jQuery(".cjs_signout_link").addClass("cjs_check_signout");
    });
  },

  initializeMobileModalOnClick: function() {
    jQuery(document).on('shown.bs.modal', function () {
      jQuery('.modal-backdrop').on('click', function(){
        jQuery('.cui-non-full-page-modal').modal("hide");
      });
    })
  }
};

//This method should be used only for the hack written above for IE,
//so please donot move this to any other file
function correctSideHeightifRequired(){
  var mainheight = jQuery("#two_column_container #main_column").height();
  var sideheight = jQuery("#two_column_container #side_column").height();
  if(mainheight > sideheight){
    jQuery("#two_column_container #side_column").height(mainheight);
  }
}

jQuery("[data-toggle=tooltip]").on("remove", function () {
  jQuery(".tooltip").tooltip('destroy');
})

jQuery(document).on('click', '[data-click]',function(event){
  if(event.currentTarget && jQuery(event.currentTarget).data("click"))
    eval(jQuery(event.currentTarget).data("click"));
});