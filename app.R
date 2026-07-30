library(shiny)
library(shinyjs)
library(writexl)
library(DT)
library(dplyr)

options(shiny.host = '172.16.2.153')
options(shiny.port = 8887)

# UI remains the same as previous version
ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$style(HTML("
      .header {
        background-color: #0073B7;
        padding: 20px;
        color: white;
        margin-bottom: 20px;
        border-radius: 5px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.2);
      }
      .sidebar-panel {
          flex: 0 0 350px;
      }
      .sidebar-panel {
        background-color: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        margin-bottom: 20px;
      }
      .hospital-name {
        font-size: 28px;
        font-weight: bold;
      }
      .department-name {
        font-size: 20px;
        margin-top: 5px;
      }
      /* Form elements */
      .form-group {
        margin-bottom: 15px;
      }
      
      .shiny-input-container {
        width: 100% !important;
      }
      .btn-group {
        margin-top: 15px;
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
      }
      
      .btn {
        flex: 1;
        min-width: 150px;
      }
    "))
  ),
  div(class = "header",
      fluidRow(
        column(2, img(src = "https://i.ibb.co/bgcR76pw/Logo.png", height = "70px")),
        column(10,
               div(class = "hospital-name", "Al-Shifa Trust Eye Hospital"),
               div(class = "department-name", "Ophthalmic Genetics")
        )
      )
  ),
  titlePanel("Family Genetics Database"),
  sidebarLayout(
    sidebarPanel(
      div(class = "sidebar-panel",
          h3("Add New Family", style = "margin-top: 0;"),
          selectizeInput("family_id", "Family ID (Select existing or enter new):", 
                         choices = NULL, 
                         options = list(create = TRUE,
                                        placeholder = 'Leave blank to generate new Family ID')),
          textInput("mr_number", "MR Number*", ""),
          textInput("name", "Full Name*", ""),
          textInput("cnic", "CNIC*", ""),
          textInput("dr_name", "Doctor's Name", ""),
          textInput("department", "Department", ""),
          textInput("disease", "Disease", ""),
          selectInput("sequecing", "Choose a Sequencing:",
                      list(`Sequencing` = list("Whole Genome", "Whole Exome", "Mitochondrial",
                                               "Sanger","SNP array", "rRNA"))),
          radioButtons("affected", "Affected Status", 
                       choices = c("Affected" = "Yes", "Not Affected" = "No"), 
                       selected = "Yes", inline = TRUE),
          radioButtons("consanguinity", "Consanguinity", 
                       choices = c("Yes" = "Yes", "No" = "No"), 
                       selected = "No", inline = TRUE),
          radioButtons("category", "Patient Category", 
                       choices = c("Free" = "Free", "Private" = "Private"), 
                       selected = "Private", inline = TRUE)),
      div(class = "btn-group",
          actionButton("add_member", "Add Member", 
                       class = "btn-primary", icon = icon("user-plus")),
          actionButton("delete_member", "Delete Selected", 
                       class = "btn-danger", icon = icon("trash-alt")),
          actionButton("submit", "Submit Family", 
                       class = "btn-success", icon = icon("save"))
      ),
      hr(),
      downloadButton("download_data", "Download Excel"),
      width = 3
    ),
    mainPanel(
      h3("Family Members to be Added"),
      DTOutput("preview_table"),
      hr(),
      h3("Existing Records (Editable)"),
      DTOutput("existing_data"),
      width = 9
    )
  )
)

server <- function(input, output, session) {
  download_path <- file.path(Sys.getenv("HOME"), "family_database.xlsx")
  
  # Initialize reactive values with proper column structure
  family_members <- reactiveVal(data.frame(
    FamilyID = character(),
    IndividualID = character(),
    MRNumber = character(),
    Name = character(),
    CNIC = character(),
    Doctor = character(),
    Department = character(),
    Disease = character(),
    Sequencing = character(),
    Affected = character(),
    Consanguinity = character(),
    Category = character(),
    stringsAsFactors = FALSE
  ))
  
  existing_data <- reactiveVal(data.frame())
  
  # Load and validate existing data
  observe({
    if (file.exists(download_path)) {
      data <- readxl::read_excel(download_path)
      
      # Ensure required columns exist
      required_cols <- c("FamilyID", "IndividualID", "MRNumber", "Name", "CNIC",
                         "Doctor", "Department", "Disease", "Sequencing",
                         "Affected", "Consanguinity", "Category")
      
      # Add missing columns with NA values
      missing_cols <- setdiff(required_cols, colnames(data))
      for (col in missing_cols) {
        data[[col]] <- NA_character_
      }
      
      # Select only required columns
      data <- data %>% select(all_of(required_cols))
      
      existing_data(data)
    } else {
      existing_data(data.frame(
        FamilyID = character(),
        IndividualID = character(),
        MRNumber = character(),
        Name = character(),
        CNIC = character(),
        Doctor = character(),
        Department = character(),
        Disease = character(),
        Sequencing = character(),
        Affected = character(),
        Consanguinity = character(),
        Category = character(),
        stringsAsFactors = FALSE
      ))
    }
  })
  
  # Update Family ID suggestions
  observe({
    updateSelectizeInput(session, "family_id", 
                         choices = unique(existing_data()$FamilyID),
                         server = TRUE)
  })
  
  generate_family_id <- function() {
    timestamp <- format(Sys.time(), "%Y%m%d%H")
    random_num <- sample(1000:9999, 1)
    paste0("FAM-", timestamp, "-", random_num)
  }
  
  # Add member logic
  observeEvent(input$add_member, {
    req(input$mr_number, input$name, input$cnic)
    
    family_id <- if (input$family_id == "") generate_family_id() else input$family_id
    
    # Get existing members from both submitted data and current session
    existing_members <- existing_data() %>% 
      filter(.data$FamilyID == family_id)
    
    current_members <- family_members() %>% 
      filter(.data$FamilyID == family_id)
    
    individual_num <- nrow(existing_members) + nrow(current_members) + 1
    
    new_member <- data.frame(
      FamilyID = family_id,
      IndividualID = paste0(family_id, "-IND", individual_num),
      MRNumber = input$mr_number,
      Name = input$name,
      CNIC = input$cnic,
      Doctor = input$dr_name,
      Department = input$department,
      Disease = input$disease,
      Sequencing = input$sequecing,
      Affected = input$affected,
      Consanguinity = input$consanguinity,
      Category = input$category,
      stringsAsFactors = FALSE
    )
    
    family_members(rbind(family_members(), new_member))
    
    updateSelectizeInput(session, "family_id", selected = family_id)
    updateTextInput(session, "mr_number", value = "")
    updateTextInput(session, "name", value = "")
    updateTextInput(session, "cnic", value = "")
  })
  
  # Delete selected members
  observeEvent(input$delete_member, {
    req(input$preview_table_rows_selected)
    family_members(family_members()[-input$preview_table_rows_selected, ])
  })
  
  # Submit family
  observeEvent(input$submit, {
    req(nrow(family_members()) > 0)
    
    updated_data <- bind_rows(existing_data(), family_members())
    existing_data(updated_data)
    write_xlsx(updated_data, download_path)
    family_members(data.frame())
    showNotification("Family submitted successfully!", type = "message")
  })
  
  # Edit existing data
  observeEvent(input$existing_data_cell_edit, {
    info <- input$existing_data_cell_edit
    updated_data <- existing_data()
    updated_data[info$row, info$col] <- info$value
    existing_data(updated_data)
    write_xlsx(updated_data, download_path)
  })
  
  # Render tables
  output$preview_table <- renderDT({
    datatable(family_members(), 
              options = list(pageLength = 5, scrollX = TRUE),
              rownames = FALSE)
  })
  
  output$existing_data <- renderDT({
    datatable(existing_data(),
              editable = TRUE,
              options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE)
  })
  
  output$download_data <- downloadHandler(
    filename = function() {
      paste("family_data_", Sys.Date(), ".xlsx", sep = "")
    },
    content = function(file) {
      write_xlsx(existing_data(), file)
    }
  )
}

shinyApp(ui = ui, server = server)