if (!require(pacman)) install.packages("pacman")
pacman::p_load(grid, ggplot2, ggfittext, shiny, shinydashboard, shinyWidgets, lubridate, glue)

fontfamily_vec <- c("Bookman", "Courier", "Palatino", "NimbusSan")
# always landscape, w, h
label_size_list <- list(address = c(3.0, 1.2), shipping = c(4, 2.2))
media_size <- c(address = "w79h252", shipping = "w167h288")

ui <- dashboardPage(
  dashboardHeader(title = "pi Label Maker", disable = TRUE),
  dashboardSidebar(disable = TRUE),
  dashboardBody(
    fluidRow(
      # control ----
      box(title = "Control", status = "info", solidHeader = TRUE, width = 12,
          fluidRow(column(6, 
                          radioGroupButtons(
                            inputId = "label_size",
                            label = "Label Size",
                            choices = c("address", "shipping"),
                            justified = TRUE,
                            checkIcon = list(
                              yes = icon("ok", 
                                         lib = "glyphicon"))
                          )
          )),
          fluidRow(
                   column(4, pickerInput("font_selected", label = "Font", choices = fontfamily_vec)),
                   column(4, 
                          # checkboxGroupInput("font_option", label = NULL, choices = c("italic", "bold"),
                          #                       inline = TRUE)
                          checkboxGroupButtons(
                            inputId = "font_option",
                            label = "Font Style",
                            choices = c("bold", "italic"),
                            checkIcon = list(
                              yes = tags$i(class = "fa fa-check-square", 
                                           style = "color: steelblue"),
                              no = tags$i(class = "fa fa-square-o", 
                                          style = "color: steelblue")),
                            justified = TRUE
                          )
                          )            
          ),
          fluidRow(column(4, sliderInput("padding", "Margin", value = 0, min = 0, max = 16))),
          fluidRow(column(8, textInput("text_input", label = NULL, placeholder = "Input one line, Enter for next line")),
                   column(2, actionButton("add_text", "Enter", icon = icon("plus"),
                                          style = "background-color: #CDDC39;")))
          
          ),
      box(title = "Preview", status = "primary", solidHeader = TRUE, width = 12,
          # height need to be used with renderplot height together
          fluidRow(column(12, plotOutput("preview", width = "99%", height = "98%")),
                   # column(12, h3("PDF Preview")),
                   # column(12, uiOutput('pdfviewer_holder')),
                   column(2, actionButton("print", "Print", icon = icon("print"),
                                                       style = "background-color: #FFEB3B;"))))
    )
  )
)
server <- function(input, output, session) {
  values <- reactiveValues()
  values$label_text <- ""
  observeEvent(input$add_text, {
    req(input$text_input != "")
    # when we added first line, there is a leading new line in beginning.
    if(values$label_text == "") {
      values$label_text <- input$text_input
    } else {
      values$label_text <- paste(values$label_text, input$text_input, sep = "\n")
    }
    updateTextInput(session = session, "text_input", value = "")
  })
  # always plot preview, also save plot so we can modify it before print to pdf
  values$plot_obj <- NULL
  # so many parameters, maybe just put inside shiny plot call, not as function.
  # so we have font problem in plot, also plot is different from final pdf effect. not sure why. so use browser pdfviewer to just preview pdf? https://stackoverflow.com/questions/19469978/displaying-a-pdf-from-a-local-drive-in-shiny
  # let's don't change plot, we need a ui to activate reactive anyway. put another pdfviwer
  # preview ----
  output$preview <- renderPlot({
    req(values$label_text != "")
    # if we set w/h with inches, we also need to set canvas. it's easier to just use a fixed aspect ratio and set final page size. if we use inch as unit, let's make canvas limit to the box, and make box slightly smaller according to margin.
    # we set boundaries, but text almost always can fit width but will not fill height.
    # single side margin ratio of whole width. usually only consider width
    # in the most setting might still have large margin, we can make box size bigger if needed. but the final print is relative, all depend on margin ratio, not absolute values.
    # we can control size either through boundary box or padding. padding is using absolute unit and not directly translating to plot, but the change is more linear and with finer control.
    # margin <- 0.00
    # boundary_size_half <- box_size * (1 - margin * 2) * 0.5
    # fontface_vec <- c("plain", "bold", "italic", "bold.italic")
    # using fixed value for now, later can switch this by input option and get it directly.
    box_size <- label_size_list[[input$label_size]]
    # default value
    selected_fontface <- "plain"
    if (!is.null(input$font_option)) selected_fontface <- paste(input$font_option, collapse = ".")
    # this control line spacing
    line_height <- 0.9
    padding <- input$padding
    point <- data.frame(x = 0, y = 0, text = values$label_text)
    # before plot ----
    # browser()
    # will have font not found warning in app, but not in script. same object, different environment. for simplicity, we should check available font list, or use sans/serif
    # in app we have different graphic devices.
    # names(pdfFonts())
    g <- ggplot(point, aes(x, y, label = text)) +
        # geom_text(fontface = "italic", family = "KaiTi") +
        geom_fit_text(
          aes(xmin = -box_size[1] / 2, xmax = box_size[1] / 2,
              ymin = -box_size[2] / 2, ymax = box_size[2] / 2),
          padding.x = unit(padding, "mm"), padding.y = unit(padding, "mm"),
          fontface = selected_fontface, family = input$font_selected, lineheight = line_height,
          grow = TRUE) +
        lims(x = box_size[1] * c(-0.5, 0.5), y = box_size[2] * c(-0.5, 0.5)) +
        coord_fixed() +
        theme_bw() +
        theme(plot.background = element_blank(),
              panel.grid.major = element_blank(),
              panel.grid.minor = element_blank(),
              axis.title.x = element_blank(),
              axis.text.x = element_blank(),
              axis.ticks.x = element_blank(),
              axis.title.y = element_blank(),
              axis.text.y = element_blank(),
              axis.ticks.y = element_blank()
        )
    # use void for final printing, but we need some boundary to show relative position in preview
    # +
    # theme_void()
    # make round corner but not working. give up on this. https://stackoverflow.com/questions/48199791/rounded-corners-in-ggplot2
    values$plot_obj <- g
    g
    # in this environment, cannot find fontfamily
    # showtext_begin() 
    # g <- ggplot() +
    #   annotate(geom = "text", x = 0, y = 0, label = "test text", size = 20,
    #            family = "NimbusSan", fontface = "bold.italic")
    # showtext_end() 
    # g
  }, height = function() {
    switch(input$label_size, address = 150, shipping = 300)
  })
  # values$pdf_name <- NULL
  # print ----
  observeEvent(input$print, {
    req(values$plot_obj)
    box_size <- label_size_list[[input$label_size]]
    # pdf("label1.pdf")
    # print(g + theme_void())
    # dev.off()
    # somehow with full size, the print is off to right side. looks like left margin cannot be changed. 
    # use fixed folder when debugging so it's easier to verify result?
    pdf_path <- tempdir()
    pdf_name <- paste0(format(now(), "%Y-%m-%d_%H-%M-%OS3"), ".pdf")
    ggsave(pdf_name, plot = values$plot_obj + theme_void(), path = pdf_path,
           width = box_size[1], height = box_size[2], units = "in")
    # lp -d DYMO_LabelWriter_400/address filename 
    # lp -o media=w79h252 label2.pdf
    # lp -o media=w167h288 label2.pdf
    # browser()
    # system2("lp", c("-o", glue("media={media_size[[input$label_size]]}"), file.path(pdf_path, "label.pdf")))
  })
  # maybe we disabled firefox pdf viewer. also there is no viewer in phone
  # output$pdfviewer_holder <- renderUI({
  #   tags$iframe(style="height:300px; width:100%", src = "2021-04-04_14-35-43.949.pdf")
  # })

}
shinyApp(ui, server)