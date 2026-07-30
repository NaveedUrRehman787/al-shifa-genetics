# app.R

# ─── Package Loading with Conditional Installation ────────────────────────────
if (!require('shiny')) { install.packages('shiny'); library(shiny) }
if (!require('shinydashboard')) { install.packages('shinydashboard'); library(shinydashboard) }
if (!require('shinyjs')) { install.packages('shinyjs'); library(shinyjs) }
if (!require('shinyWidgets')) { install.packages('shinyWidgets'); library(shinyWidgets) }
if (!require('dplyr')) { install.packages('dplyr'); library(dplyr) }
if (!require('writexl')) { install.packages('writexl'); library(writexl) }
if (!require('readxl')) { install.packages('readxl'); library(readxl) }
if (!require('tools')) { install.packages('tools'); library(tools) }

options(shiny.host = "127.0.0.1")
options(shiny.port = 5173)
# ─── Data File Path ───────────────────────────────────────────────────────────
DATA_FILE <- "family_data.xlsx"

# ─── UI Layout ────────────────────────────────────────────────────────────────
ui <- dashboardPage(
  dashboardHeader(
    title = span(
      img(src = "https://i.ibb.co/bgcR76p/Logo.png", height = "30px", style = "margin-right:10px;"),
      "Al-Shifa Genetics DB"
    ),
    titleWidth = 300
  ),
  
  dashboardSidebar(
    width = 300,
    sidebarMenu(
      id = "tabs",
      menuItem("Dashboard",           tabName = "dashboard",          icon = icon("dashboard")),
      menuItem("Add Family",         tabName = "add_family",         icon = icon("plus")),
      menuItem("View Records",       tabName = "view_records",       icon = icon("table")),
      menuItem("Remaining Analysis", tabName = "remaining_analysis",  icon = icon("flask")),
      menuItem("Settings",           tabName = "settings",           icon = icon("cog"))
    )
  ),
  
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        .main-header .navbar { background-color: #337ab7 !important; }
        .main-header .logo { background-color: #337ab7 !important; color: white !important; font-weight: bold; }
        .main-sidebar { background-color: #f4f4f4 !important; }
        .content-wrapper { background-color: #f9f9f9 !important; }
        .box, .info-box { border-radius: 5px !important; box-shadow: 0 2px 5px rgba(0,0,0,0.1) !important; }
        .form-control { border-radius: 3px; border: 1px solid #ccc; }
        .form-control:focus { border-color: #337ab7; box-shadow: 0 0 0 0.2rem rgba(51, 122, 183, 0.25); }
        .btn { border-radius: 3px; padding: 8px 16px; }
        
        /* Table container with enhanced scrolling */
        .table-container { 
          overflow-x: auto !important;
          overflow-y: auto;
          max-height: 600px;
          background: white; 
          border-radius: 8px; 
          box-shadow: 0 2px 8px rgba(0,0,0,0.1); 
          border: 1px solid #dee2e6;
          position: relative;
          margin-bottom: 20px;
        }
        
        .shiny-table {
          width: 100% !important;
          table-layout: auto;
        }
        
        .shiny-table th { 
          background-color: #337ab7; 
          color: white; 
          border: none; 
          white-space: nowrap; 
          font-weight: bold; 
          padding: 8px 10px; 
          text-align: left; 
          vertical-align: middle;
          font-size: 12px;
          position: sticky;
          top: 0;
          z-index: 10;
        }
        
        .shiny-table td { 
          border-color: #ddd; 
          padding: 6px 8px; 
          text-align: left; 
          vertical-align: middle; 
          word-wrap: break-word;
          max-width: 200px;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        
        .shiny-table tr:hover td {
          background-color: #f5f5f5;
        }
        
        .table-striped tbody tr:nth-of-type(odd) { 
          background-color: #f9f9f9; 
        }
        
        /* Scrollbar styling */
        .table-container::-webkit-scrollbar {
          height: 8px;
          width: 8px;
        }
        
        .table-container::-webkit-scrollbar-track {
          background: #f1f1f1;
          border-radius: 4px;
        }
        
        .table-container::-webkit-scrollbar-thumb {
          background: #337ab7;
          border-radius: 4px;
        }
        
        .table-container::-webkit-scrollbar-thumb:hover {
          background: #286090;
        }
        
        .search-controls { margin-bottom:20px; padding:20px; background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); border-radius:8px; border:1px solid #dee2e6; box-shadow:0 2px 4px rgba(0,0,0,0.1); }
        .search-controls .form-control { border-radius:6px; border:2px solid #ced4da; transition: all 0.3s ease; height:38px; }
        .search-controls .form-control:focus { border-color:#337ab7; box-shadow:0 0 0 0.2rem rgba(51,122,183,0.25); transform:translateY(-1px); }
        .search-controls .form-group { margin-bottom:15px; }
        .search-controls .form-group label { margin-bottom:8px; display:block; }
        .search-controls .btn { border-radius:6px; font-weight:600; transition: all 0.3s ease; margin-top:25px; height:38px; }
        .search-controls .btn:hover { transform:translateY(-1px); box-shadow:0 4px 8px rgba(0,0,0,0.15); }
        .pagination-controls { margin-top:20px; text-align:center; padding:20px; background:linear-gradient(135deg, #ffffff 0%, #f8f9fa 100%); border-radius:8px; border:1px solid #dee2e6; box-shadow:0 2px 4px rgba(0,0,0,0.1); display:flex; justify-content:center; align-items:center; gap:15px; }
        .pagination-controls .btn { border-radius:6px; font-weight:600; margin:0 10px; transition: all 0.3s ease; height:40px; min-width:100px; }
        .pagination-controls .btn:hover { transform:translateY(-1px); box-shadow:0 4px 8px rgba(0,0,0,0.15); }
        .pagination-controls .btn:disabled { opacity:0.5; cursor:not-allowed; transform:none; }
        .records-info { background:linear-gradient(135deg, #337ab7 0%, #286090 100%); color:white; padding:12px 15px; border-radius:6px; margin-bottom:15px; font-size:14px; font-weight:500; text-align:center; box-shadow:0 2px 4px rgba(0,0,0,0.1); }
      "))
    ),
    
    tabItems(
      
      # — Dashboard Tab —
      tabItem(tabName = "dashboard",
              fluidRow(
                column(12,
                       h2("Al-Shifa Genetics Database"),
                       p("Manage family genetics records and data")
                )
              ),
              fluidRow(
                infoBoxOutput("total_families",     width = 3),
                infoBoxOutput("total_individuals",  width = 3),
                infoBoxOutput("total_diseases",     width = 3),
                infoBoxOutput("total_doctors",      width = 3)
              ),
              fluidRow(
                box(title = "Quick Actions", status = "primary", solidHeader = TRUE, width = 12,
                    column(3, actionButton("quick_add",      "Add New Family",       class = "btn btn-primary btn-lg",   style = "width:100%;")),
                    column(3, actionButton("quick_view",     "View All Records",     class = "btn btn-success btn-lg",   style = "width:100%;")),
                    column(3, downloadButton("quick_download","Download Data",        class = "btn btn-warning btn-lg",   style = "width:100%;")),
                    column(3, actionButton("quick_search",   "Search Records",       class = "btn btn-info btn-lg",      style = "width:100%;"))
                )
              )
      ),
      
      # — Add Family Tab —
      tabItem(tabName = "add_family",
              fluidRow(
                column(12,
                       box(title = "Family Selection", status = "info", solidHeader = TRUE, width = 12,
                           fluidRow(
                             column(6,
                                    radioButtons("family_mode", "Select Mode:",
                                                 choices = c("New Family" = "new", "Existing Family" = "existing"),
                                                 selected = "new")
                             ),
                             column(6,
                                    conditionalPanel(
                                      condition = "input.family_mode == 'existing'",
                                      selectInput("existing_family", "Select Existing Family:", choices = c("Loading families..." = ""))
                                    )
                             )
                           )
                       )
                )
              ),
              
              fluidRow(
                column(6,
                       box(title = "Add Family Member", status = "primary", solidHeader = TRUE, width = 12,
                           textInput("mr_number",      "MR Number"),
                           textInput("name",           "Full Name"),
                           textInput("cnic",           "CNIC"),
                           textInput("dr_name",        "Doctor's Name"),
                           numericInput("age",         "Age", value = NULL, min = 0, max = 120),
                           selectInput("gender",       "Gender", choices = c("", "Male", "Female", "Other")),
                           textInput("batch_number",   "Batch Number"),
                           selectInput("department",   "Department", choices = c("", "Cornea", "Genetics", "Pediatrics", "Retina", "Oculoplastics",
                                                                                 "Ocular Oncology", "Glaucoma")),
                           textInput("disease",        "Disease"),
                           selectInput("sequencing",   "Sequencing Type:",
                                       choices = c("", "Whole Genome", "Whole Exome", "Mitochondrial", "Sanger", "SNP array", "rRNA")),
                           textInput("sample_collected","Sample Collected"),
                           radioButtons("affected",    "Affected Status", choices = c("Affected" = "Yes", "Not Affected" = "No"), selected = "Yes"),
                           radioButtons("consanguinity","Consanguinity", choices = c("Yes" = "Yes", "No" = "No"), selected = "No"),
                           radioButtons("category",    "Patient Category", choices = c("Free" = "Free", "Private" = "Private"), selected = "Private"),
                           hr(),
                           actionButton("add_member",   "Add Member",         class = "btn btn-primary"),
                           actionButton("delete_member","Delete Selected",    class = "btn btn-danger"),
                           actionButton("submit",       "Submit Family",      class = "btn btn-success"),
                           actionButton("clear_form",   "Clear Form",         class = "btn btn-warning")
                       )
                ),
                column(6,
                       box(title = "Family Members Preview", status = "info", solidHeader = TRUE, width = 12,
                           div(class = "table-container", tableOutput("preview_table")), br(),
                           h4("Recent Records (Last 10)"),
                           div(class = "table-container", tableOutput("existing_data"))
                       )
                )
              )
      ),
      
      # — View Records Tab —
      tabItem(tabName = "view_records",
              fluidRow(
                box(title = "All Family Records", status = "primary", solidHeader = TRUE, width = 12,
                    div(class = "search-controls",
                        h4("Search & Filter Records", style = "margin-bottom:20px; color:#495057;"),
                        fluidRow(
                          column(3, textInput("search_records", "Search Records", placeholder = "Search by name, MR number, family ID...")),
                          column(2, selectInput("search_field", "Search Field:",
                                                choices = c("All Fields" = "all", "Name" = "Name", "MR Number" = "MRNumber", "Family ID" = "FamilyID", "Disease" = "Disease", "Doctor" = "Doctor"), selected = "all")),
                          column(2, selectInput("records_per_page", "Records per Page:", choices = c(10,25,50,100), selected = 25)),
                          column(3, selectInput("display_fields", "Display Fields:", choices = c("Default Fields" = "default", "All Fields" = "all"), selected = "default")),
                          column(2, actionButton("clear_search", "Clear", class = "btn btn-warning"))
                        )
                    ),
                    hr(),
                    div(class = "records-info", verbatimTextOutput("records_info")),
                    div(class = "table-container", 
                        conditionalPanel(condition = "input.display_fields == 'all'",
                                         tags$div(class = "alert alert-info", style = "margin-bottom: 10px; font-size: 12px;",
                                                  HTML("<i class='fa fa-info-circle'></i> <strong>Tip:</strong> Table shows all fields. Use horizontal scroll to view more columns."))),
                        tableOutput("all_records_table")),
                    div(class = "pagination-controls",
                        actionButton("prev_page", "Previous", class = "btn btn-primary", id = "prev_page_btn"),
                        div(style = "font-weight:600; color:#495057; padding:0 20px;", textOutput("page_info")),
                        actionButton("next_page", "Next", class = "btn btn-primary", id = "next_page_btn")
                    )
                )
              )
      ),
      
      # — Remaining Analysis Tab —
      tabItem(tabName = "remaining_analysis",
              fluidRow(
                column(12,
                       h2("Bioinformatics Analysis – Remaining Cases"),
                       p("Analyze cases that are ready for bioinformatics processing")
                )
              ),
              fluidRow(
                infoBoxOutput("pending_analysis",   width = 4),
                infoBoxOutput("completed_analysis", width = 4),
                infoBoxOutput("total_cases",        width = 4)
              ),
              fluidRow(
                box(title = "Analysis Controls", status = "primary", solidHeader = TRUE, width = 12,
                    fluidRow(
                      column(6, selectInput("analysis_individual", "Select Individual for Analysis:", choices = c("Loading individuals..." = ""))),
                      column(6, selectInput("analysis_type", "Analysis Type:",
                                            choices = c("Whole Genome Analysis" = "whole_genome", "Whole Exome Analysis" = "whole_exome", "Variant Calling" = "variant_calling", "Pathway Analysis" = "pathway_analysis", "Population Genetics" = "population_genetics"))),
                      column(12, actionButton("start_analysis", "Start Bioinformatics Analysis", class = "btn btn-success btn-lg", style = "width:100%; margin-top:25px;"))
                    )
                )
              ),
              fluidRow(
                box(title = "Cases Ready for Bioinformatics Analysis", status = "info", solidHeader = TRUE, width = 12,
                    div(class = "table-container", tableOutput("analysis_queue_table")), br(),
                    actionButton("refresh_analysis_queue", "Refresh Queue", class = "btn btn-info"),
                    downloadButton("export_analysis_data",   "Export Analysis Data", class = "btn btn-warning")
                )
              )
      ),
      
      # — Settings Tab —
      tabItem(tabName = "settings",
              fluidRow(
                box(title = "Application Settings", status = "primary", solidHeader = TRUE, width = 12,
                    h4("Data Management"),
                    p("Current data storage: ", tags$code("Excel File: "), DATA_FILE), br(),
                    downloadButton("export_all_data", "Export All Data", class = "btn btn-success"), br(), br(),
                    actionButton("clear_all_data", "Clear All Data", class = "btn btn-danger"), br(), br(),
                    h4("System Information"),
                    p("Application Version: ", tags$strong("2.0")),
                    p("Last Updated: ", tags$strong(format(Sys.Date(), "%B %d, %Y")))
                )
              )
      )
    )
  )
)

# ─── Server Logic ─────────────────────────────────────────────────────────────

server <- function(input, output, session) {
  # ─── Load Existing Data from Excel File ─────────────────────────────────────
  load_family_data <- function() {
    if (file.exists(DATA_FILE)) {
      # Read the existing data
      existing_data <- tryCatch({
        read_xlsx(DATA_FILE)
      }, error = function(e) {
        data.frame()
      })
      
      # Define the expected columns with proper types
      expected_cols <- data.frame(
        FamilyID = character(),
        IndividualID = character(),
        MRNumber = character(),
        Name = character(),
        CNIC = character(),
        Age = numeric(),
        Gender = character(),
        BatchNumber = character(),
        Doctor = character(),
        Department = character(),
        Disease = character(),
        Sequencing = character(),
        SampleCollected = character(),
        Affected = character(),
        Consanguinity = character(),
        Category = character(),
        AnalysisStatus = character(),
        stringsAsFactors = FALSE
      )
      
      # If no data exists, return empty structure
      if (nrow(existing_data) == 0) {
        return(expected_cols)
      }
      
      # Add missing columns with default values
      for (col in names(expected_cols)) {
        if (!col %in% names(existing_data)) {
          if (is.character(expected_cols[[col]])) {
            existing_data[[col]] <- as.character(NA)
          } else if (is.numeric(expected_cols[[col]])) {
            existing_data[[col]] <- as.numeric(NA)
          }
        }
      }
      
      # Ensure correct data types
      for (col in names(expected_cols)) {
        if (col %in% names(existing_data)) {
          if (is.character(expected_cols[[col]])) {
            existing_data[[col]] <- as.character(existing_data[[col]])
          } else if (is.numeric(expected_cols[[col]])) {
            existing_data[[col]] <- as.numeric(existing_data[[col]])
          }
        }
      }
      
      # Select only the expected columns and handle NA values
      existing_data <- existing_data[, names(expected_cols)]
      
      # Replace NA with appropriate defaults
      existing_data$AnalysisStatus[is.na(existing_data$AnalysisStatus)] <- "Individual Complete - Ready for Bioinformatics"
      existing_data$Affected[is.na(existing_data$Affected)] <- "Yes"
      existing_data$Consanguinity[is.na(existing_data$Consanguinity)] <- "No"
      existing_data$Category[is.na(existing_data$Category)] <- "Private"
      
      return(existing_data)
    } else {
      # Return empty data frame with expected structure
      return(data.frame(
        FamilyID = character(),
        IndividualID = character(),
        MRNumber = character(),
        Name = character(),
        CNIC = character(),
        Age = numeric(),
        Gender = character(),
        BatchNumber = character(),
        Doctor = character(),
        Department = character(),
        Disease = character(),
        Sequencing = character(),
        SampleCollected = character(),
        Affected = character(),
        Consanguinity = character(),
        Category = character(),
        AnalysisStatus = character(),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  # ─── Save Data to Excel File ────────────────────────────────────────────────
  save_family_data <- function(data) {
    if (nrow(data) > 0) {
      tryCatch({
        write_xlsx(data, path = DATA_FILE)
      }, error = function(e) {
        message("Error saving data: ", e$message)
      })
    }
  }
  
  # Initialize data storage
  family_data <- reactiveVal()
  
  # Load data on app start
  observe({
    data <- load_family_data()
    family_data(data)
  })
  
  # Reactive data storage for new family before submit
  family_members <- reactiveVal(data.frame(
    FamilyID = character(),
    IndividualID = character(),
    MRNumber = character(),
    Name = character(),
    CNIC = character(),
    Age = numeric(),
    Gender = character(),
    BatchNumber = character(),
    Doctor = character(),
    Department = character(),
    Disease = character(),
    Sequencing = character(),
    SampleCollected = character(),
    Affected = character(),
    Consanguinity = character(),
    Category = character(),
    AnalysisStatus = character(),
    stringsAsFactors = FALSE
  ))
  
  # Save data whenever it changes
  observe({
    data <- family_data()
    if (nrow(data) > 0) {
      save_family_data(data)
    }
  })
  
  # Update existing_family selection when families change
  observe({
    data <- family_data()
    if (nrow(data) > 0 && "FamilyID" %in% names(data)) {
      fams <- unique(data$FamilyID)
      choices <- c("Select a family..." = "", setNames(fams, fams))
      updateSelectInput(session, "existing_family", choices = choices)
    } else {
      updateSelectInput(session, "existing_family", choices = c("No families available" = ""))
    }
  })
  
  # Update analysis_individual selection when data changes
  observe({
    data <- family_data()
    if (nrow(data) > 0 && "IndividualID" %in% names(data)) {
      # Get individuals ready for analysis
      ready_individuals <- data[data$AnalysisStatus == "Individual Complete - Ready for Bioinformatics", ]
      if (nrow(ready_individuals) > 0) {
        choices <- setNames(ready_individuals$IndividualID, 
                            paste0(ready_individuals$Name, " (", ready_individuals$IndividualID, ")"))
        updateSelectInput(session, "analysis_individual", choices = choices)
      } else {
        updateSelectInput(session, "analysis_individual", choices = c("No individuals ready for analysis" = ""))
      }
    } else {
      updateSelectInput(session, "analysis_individual", choices = c("No data available" = ""))
    }
  })
  
  # Generate unique FamilyID helper
  generate_family_id <- function() {
    paste0("FAM-", format(Sys.time(), "%Y%m%d%H%M%S"), "-", sample(1000:9999, 1))
  }
  
  # — Info boxes on Dashboard —
  output$total_families <- renderInfoBox({
    df <- family_data()
    n <- if (nrow(df) > 0) length(unique(df$FamilyID)) else 0
    infoBox("Total Families", value = n, icon = icon("group"), color = "blue")
  })
  
  output$total_individuals <- renderInfoBox({
    n <- nrow(family_data())
    infoBox("Total Individuals", value = n, icon = icon("user"), color = "green")
  })
  
  output$total_diseases <- renderInfoBox({
    df <- family_data()
    n <- if (nrow(df) > 0 && "Disease" %in% names(df)) {
      length(unique(df$Disease[df$Disease != "" & !is.na(df$Disease)]))
    } else {
      0
    }
    infoBox("Total Diseases", value = n, icon = icon("stethoscope"), color = "red")
  })
  
  output$total_doctors <- renderInfoBox({
    df <- family_data()
    n <- if (nrow(df) > 0 && "Doctor" %in% names(df)) {
      length(unique(df$Doctor[df$Doctor != "" & !is.na(df$Doctor)]))
    } else {
      0
    }
    infoBox("Total Doctors", value = n, icon = icon("user-md"), color = "purple")
  })
  
  # Quick Actions navigation
  observeEvent(input$quick_add,   updateTabItems(session, "tabs", "add_family"))
  observeEvent(input$quick_view,  updateTabItems(session, "tabs", "view_records"))
  observeEvent(input$quick_search,updateTabItems(session, "tabs", "view_records"))
  
  # — Add Member Logic —
  observeEvent(input$add_member, {
    # Basic validation
    if (input$mr_number == "" || input$name == "" || input$cnic == "") {
      showNotification("Please fill in all required fields (MR Number, Name, CNIC)", type = "error", duration = 5)
      return()
    }
    # if (nchar(input$cnic) != 1 || !grepl("^\\d+$", input$cnic)) {
    #   showNotification("CNIC must be filled", type = "error", duration = 5)
    #   return()
    # }
    
    if (input$family_mode == "existing") {
      if (input$existing_family == "" || input$existing_family == "Select a family...") {
        showNotification("Please select an existing family", type = "error", duration = 5)
        return()
      }
      data <- family_data()
      fam_data <- data[data$FamilyID == input$existing_family, ]
      num <- nrow(fam_data) + 1
      individual_id <- sprintf("%s-IND%03d", input$existing_family, num)
      
      new_member <- data.frame(
        FamilyID = input$existing_family,
        IndividualID = individual_id,
        MRNumber = input$mr_number,
        Name = input$name,
        CNIC = input$cnic,
        Age = as.numeric(input$age),
        Gender = input$gender,
        BatchNumber = input$batch_number,
        Doctor = input$dr_name,
        Department = input$department,
        Disease = input$disease,
        Sequencing = input$sequencing,
        SampleCollected = input$sample_collected,
        Affected = input$affected,
        Consanguinity = input$consanguinity,
        Category = input$category,
        AnalysisStatus = "Individual Complete - Ready for Bioinformatics",
        stringsAsFactors = FALSE
      )
      updated <- rbind(data, new_member)
      family_data(updated)
      showNotification("Member added to existing family successfully!", type = "default", duration = 3)
      
    } else {
      cur <- family_members()
      if (nrow(cur) == 0) {
        fid <- generate_family_id()
      } else {
        fid <- cur$FamilyID[1]
      }
      num <- nrow(cur) + 1
      individual_id <- sprintf("%s-IND%03d", fid, num)
      
      new_member <- data.frame(
        FamilyID = fid,
        IndividualID = individual_id,
        MRNumber = input$mr_number,
        Name = input$name,
        CNIC = input$cnic,
        Age = as.numeric(input$age),
        Gender = input$gender,
        BatchNumber = input$batch_number,
        Doctor = input$dr_name,
        Department = input$department,
        Disease = input$disease,
        Sequencing = input$sequencing,
        SampleCollected = input$sample_collected,
        Affected = input$affected,
        Consanguinity = input$consanguinity,
        Category = input$category,
        AnalysisStatus = "Individual Complete - Ready for Bioinformatics",
        stringsAsFactors = FALSE
      )
      family_members(rbind(cur, new_member))
      showNotification("Family member added successfully!", type = "default", duration = 3)
    }
    
    # Clear form inputs
    resetFields <- function() {
      updateTextInput(session, "mr_number", value = "")
      updateTextInput(session, "name",      value = "")
      updateTextInput(session, "cnic",      value = "")
      updateNumericInput(session, "age",    value = NULL)
      updateSelectInput(session, "gender", selected = "")
      updateTextInput(session, "batch_number", value = "")
      updateTextInput(session, "dr_name",  value = "")
      updateSelectInput(session, "department", selected = "")
      updateTextInput(session, "disease", value = "")
      updateSelectInput(session, "sequencing", selected = "")
      updateTextInput(session, "sample_collected", value = "")
      updateRadioButtons(session, "affected", selected = "Yes")
      updateRadioButtons(session, "consanguinity", selected = "No")
      updateRadioButtons(session, "category", selected = "Private")
    }
    resetFields()
  })
  
  # — Delete Member (New Family only) —
  observeEvent(input$delete_member, {
    if (input$family_mode == "new") {
      cur <- family_members()
      if (nrow(cur) > 0) {
        family_members(cur[-nrow(cur), ])
        showNotification("Last member removed from family!", type = "default", duration = 3)
      } else {
        showNotification("No members to delete!", type = "warning", duration = 3)
      }
    } else {
      showNotification("Delete functionality only available for new families!", type = "info", duration = 3)
    }
  })
  
  # — Clear Form —
  observeEvent(input$clear_form, {
    updateRadioButtons(session, "family_mode", selected = "new")
    resetFields <- function() {
      updateTextInput(session, "mr_number",      value = "")
      updateTextInput(session, "name",           value = "")
      updateTextInput(session, "cnic",           value = "")
      updateNumericInput(session, "age",         value = NULL)
      updateSelectInput(session, "gender",       selected = "")
      updateTextInput(session, "batch_number",   value = "")
      updateTextInput(session, "dr_name",        value = "")
      updateSelectInput(session, "department",   selected = "")
      updateTextInput(session, "disease",        value = "")
      updateSelectInput(session, "sequencing",   selected = "")
      updateTextInput(session, "sample_collected", value = "")
      updateRadioButtons(session, "affected",    selected = "Yes")
      updateRadioButtons(session, "consanguinity", selected = "No")
      updateRadioButtons(session, "category",    selected = "Private")
    }
    resetFields()
    showNotification("Form cleared!", type = "default", duration = 2)
  })
  
  # — Submit Family —
  observeEvent(input$submit, {
    cur <- family_members()
    if (nrow(cur) == 0) {
      showNotification("No family members to submit. Add at least one member.", type = "error", duration = 5)
      return()
    }
    updated <- rbind(family_data(), cur)
    family_data(updated)
    family_members(data.frame())  # Clear new family buffer
    showNotification("Family data successfully submitted!", type = "default", duration = 5)
  })
  
  # — Preview Tables in Add Family Tab —
  output$preview_table <- renderTable({
    if (input$family_mode == "existing" && nzchar(input$existing_family)) {
      data <- family_data()
      fam <- data[data$FamilyID == input$existing_family, ]
      if (nrow(fam) > 0) fam[, c("IndividualID","Name","MRNumber","Age","BatchNumber","Disease","Affected")]
      else data.frame(Message = "No members in this family yet")
    } else {
      fam <- family_members()
      if (nrow(fam) > 0) fam[, c("IndividualID","Name","MRNumber","Age","BatchNumber","Disease","Affected")]
      else data.frame(Message = "No family members added yet")
    }
  }, striped = TRUE, bordered = TRUE, align = "c")
  
  output$existing_data <- renderTable({
    data <- family_data()
    if (nrow(data) > 0) {
      recent <- tail(data, 10)
      cols <- intersect(c("FamilyID","Name","Age","BatchNumber","Disease"), names(recent))
      recent[, cols]
    } else {
      data.frame(Message = "No existing records")
    }
  }, striped = TRUE, bordered = TRUE, align = "c")
  
  # — Record Filtering & Pagination in View Records —
  filtered_data <- reactive({
    data <- family_data()
    if (nrow(data) == 0) {
      return(data.frame())
    }
    st <- input$search_records
    sf <- input$search_field
    if (!is.null(st) && nzchar(st)) {
      if (sf == "all") {
        txtcols <- sapply(data, is.character)
        keep <- apply(data[, txtcols, drop = FALSE], 1, function(r) any(grepl(st, r, ignore.case = TRUE)))
        data <- data[keep, , drop = FALSE]
      } else if (sf %in% names(data)) {
        data <- data[grepl(st, data[[sf]], ignore.case = TRUE), , drop = FALSE]
      }
    }
    data
  })
  
  current_page <- reactiveVal(1)
  
  observeEvent(input$prev_page, {
    if (current_page() > 1) current_page(current_page() - 1)
  })
  
  observeEvent(input$next_page, {
    tot <- ceiling(nrow(filtered_data()) / as.numeric(input$records_per_page))
    if (current_page() < tot) current_page(current_page() + 1)
  })
  
  observe({
    data <- filtered_data()
    totp <- ceiling(nrow(data) / as.numeric(input$records_per_page))
    pg <- current_page()
    toggleState("prev_page_btn", condition = pg > 1)
    toggleState("next_page_btn", condition = pg < totp && nrow(data) > 0)
  })
  
  output$records_info <- renderText({
    data <- filtered_data()
    nr <- nrow(data)
    rpp <- as.numeric(input$records_per_page)
    tp <- ceiling(nr / rpp)
    pg <- current_page()
    if (nr == 0) "No records found"
    else sprintf("Showing %d to %d of %d records (Page %d of %d)", (pg - 1) * rpp + 1, min(pg * rpp, nr), nr, pg, tp)
  })
  
  output$page_info <- renderText({
    data <- filtered_data()
    nr <- nrow(data)
    rpp <- as.numeric(input$records_per_page)
    tp <- ceiling(nr / rpp)
    pg <- current_page()
    if (nr == 0) "Page 0 of 0" else sprintf("Page %d of %d", pg, tp)
  })
  
  output$all_records_table <- renderTable({
    data <- filtered_data()
    if (nrow(data) == 0) return(data.frame(Message = "No records found"))
    
    rpp <- as.numeric(input$records_per_page)
    pg <- current_page()
    start_idx <- ((pg - 1) * rpp + 1)
    end_idx <- min(pg * rpp, nrow(data))
    disp <- data[start_idx:end_idx, , drop = FALSE]
    
    if (input$display_fields == "default") {
      # Show only essential fields for better readability
      dflds <- c("IndividualID", "MRNumber", "Name", "CNIC", "Age", "Doctor", "Disease")
      disp <- disp[, intersect(dflds, names(disp)), drop = FALSE]
    } else {
      # For "all" fields, truncate long text values and optimize column names
      max_chars <- 20
      for (col in names(disp)) {
        if (is.character(disp[[col]])) {
          disp[[col]] <- ifelse(nchar(disp[[col]]) > max_chars, 
                                paste0(substr(disp[[col]], 1, max_chars - 3), "..."), 
                                disp[[col]])
        }
      }
      
      # Rename columns to shorter versions for better fit
      col_renames <- c(
        "IndividualID" = "ID",
        "MRNumber" = "MR#",
        "BatchNumber" = "Batch",
        "SampleCollected" = "Sample",
        "Consanguinity" = "Consang",
        "AnalysisStatus" = "Status",
        "Department" = "Dept"
      )
      
      for (old_name in names(col_renames)) {
        if (old_name %in% names(disp)) {
          names(disp)[names(disp) == old_name] <- col_renames[old_name]
        }
      }
    }
    
    disp
  }, 
  striped = TRUE, 
  bordered = TRUE, 
  align = "c",
  spacing = "xs"
  )
  
  # — Remaining Analysis: Info Boxes —
  output$pending_analysis <- renderInfoBox({
    df <- family_data()
    n <- if ("AnalysisStatus" %in% names(df)) sum(df$AnalysisStatus == "Individual Complete - Ready for Bioinformatics", na.rm = TRUE) else 0
    infoBox("Pending Analysis", value = n, icon = icon("clock"), color = "yellow")
  })
  
  output$completed_analysis <- renderInfoBox({
    df <- family_data()
    n <- if ("AnalysisStatus" %in% names(df)) sum(df$AnalysisStatus == "Bioinformatics Analysis Complete", na.rm = TRUE) else 0
    infoBox("Completed Analysis", value = n, icon = icon("check-circle"), color = "green")
  })
  
  output$total_cases <- renderInfoBox({
    n <- nrow(family_data())
    infoBox("Total Cases", value = n, icon = icon("users"), color = "blue")
  })
  
  # — Analysis Controls & Tables —
  output$analysis_queue_table <- renderTable({
    df <- family_data()
    if (nrow(df) == 0 || !"AnalysisStatus" %in% names(df)) return(data.frame(Message = "No data available"))
    ready <- df[df$AnalysisStatus == "Individual Complete - Ready for Bioinformatics", ]
    if (nrow(ready) > 0) ready[, intersect(c("IndividualID","Name","MRNumber","BatchNumber","Disease","Sequencing"), names(ready))]
    else data.frame(Message = "No cases ready for analysis")
  }, striped = TRUE, bordered = TRUE, align = "c")
  
  observeEvent(input$start_analysis, {
    if (!nzchar(input$analysis_individual) || !nzchar(input$analysis_type)) {
      showNotification("Please select both an individual and analysis type", type = "error", duration = 5)
      return()
    }
    
    df <- family_data()
    individual_id <- input$analysis_individual
    
    # Find the individual
    individual_idx <- which(df$IndividualID == individual_id)
    
    if (length(individual_idx) == 0) {
      showNotification("Selected individual not found in database", type = "error", duration = 5)
      return()
    }
    
    showNotification(sprintf("Starting %s for %s...", input$analysis_type, individual_id), type = "default", duration = 3)
    
    # Update the analysis status
    df$AnalysisStatus[individual_idx] <- "Bioinformatics Analysis Complete"
    
    # Save the updated data
    family_data(df)
    
    showNotification(sprintf("Analysis completed for %s!", individual_id), type = "success", duration = 5)
  })
  
  observeEvent(input$refresh_analysis_queue, { 
    showNotification("Analysis queue refreshed!", type = "default", duration = 2) 
  })
  
  output$export_analysis_data <- downloadHandler(
    filename = function() {
      paste0("bioinformatics_analysis_data_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
    },
    content = function(file) {
      df <- family_data()
      if (nrow(df) == 0) stop("No data available for export")
      
      # Create summary data
      summary_df <- data.frame(
        Metric = c("Total Cases", "Pending Analysis", "Completed Analysis", "Total Families"),
        Count = c(
          nrow(df),
          sum(df$AnalysisStatus == "Individual Complete - Ready for Bioinformatics", na.rm = TRUE),
          sum(df$AnalysisStatus == "Bioinformatics Analysis Complete", na.rm = TRUE),
          length(unique(df$FamilyID))
        )
      )
      
      # Create list of data frames to export
      list_out <- list(
        Summary = summary_df,
        Analysis_Queue = df[df$AnalysisStatus == "Individual Complete - Ready for Bioinformatics", ],
        Completed_Analysis = df[df$AnalysisStatus == "Bioinformatics Analysis Complete", ],
        All_Data = df
      )
      
      # Write to Excel
      write_xlsx(list_out, path = file)
    }
  )
  
  # — Settings: Export & Clear All Data —
  output$export_all_data <- downloadHandler(
    filename = function() {
      paste0("family_genetics_data_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
    },
    content = function(file) {
      df <- family_data()
      if (nrow(df) == 0) stop("No data available for export")
      
      # Create summary data
      summary_df <- data.frame(
        Metric = c("Total Families", "Total Individuals", "Affected Individuals", "Consanguineous Cases"),
        Count = c(
          length(unique(df$FamilyID)),
          nrow(df),
          sum(df$Affected == "Yes", na.rm = TRUE),
          sum(df$Consanguinity == "Yes", na.rm = TRUE)
        )
      )
      
      # Write to Excel
      write_xlsx(list(Summary = summary_df, All_Data = df), path = file)
    }
  )
  
  observeEvent(input$clear_all_data, {
    showModal(modalDialog(
      title = "Clear All Data",
      "Are you sure you want to clear all data? This action cannot be undone.",
      footer = tagList(modalButton("Cancel"), actionButton("confirm_clear", "Clear All Data", class = "btn btn-danger"))
    ))
  })
  
  observeEvent(input$confirm_clear, {
    # Clear all data
    empty_df <- data.frame(
      FamilyID = character(),
      IndividualID = character(),
      MRNumber = character(),
      Name = character(),
      CNIC = character(),
      Age = numeric(),
      Gender = character(),
      BatchNumber = character(),
      Doctor = character(),
      Department = character(),
      Disease = character(),
      Sequencing = character(),
      SampleCollected = character(),
      Affected = character(),
      Consanguinity = character(),
      Category = character(),
      AnalysisStatus = character(),
      stringsAsFactors = FALSE
    )
    
    family_data(empty_df)
    family_members(empty_df)
    
    # Delete the data file
    if (file.exists(DATA_FILE)) {
      file.remove(DATA_FILE)
    }
    
    showNotification("All data cleared successfully!", type = "success", duration = 3)
    removeModal()
  })
  
  # — Quick Download —
  output$quick_download <- downloadHandler(
    filename = function() {
      paste0("family_genetics_data_", format(Sys.time(), "%Y%m%d%H%M%S"), ".xlsx")
    },
    content = function(file) {
      df <- family_data()
      if (nrow(df) == 0) stop("No data available for export")
      
      # Create summary data
      summary_df <- data.frame(
        Metric = c("Total Families", "Total Individuals", "Affected Individuals", "Consanguineous Cases"),
        Count = c(
          length(unique(df$FamilyID)),
          nrow(df),
          sum(df$Affected == "Yes", na.rm = TRUE),
          sum(df$Consanguinity == "Yes", na.rm = TRUE)
        )
      )
      
      # Write to Excel
      write_xlsx(list(Summary = summary_df, All_Data = df), path = file)
    }
  )
}

# ─── Launch App ───────────────────────────────────────────────────────────────
shinyApp(ui = ui, server = server)
