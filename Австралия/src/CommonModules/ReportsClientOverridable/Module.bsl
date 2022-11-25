#Region Public

// It appears before starting to generate a report.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   Cancel - Boolean - if it is set to True, report generation process will be stopped.
//       To restart generation process, use the ReportsClient.GenerateReport().
//       
//
Procedure BeforeGenerate(ReportForm, Cancel) Export
	
EndProcedure

// It appears after report is generated.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   ReportCreated - Boolean - True if the report has been successfully generated.
//
Procedure AfterGenerate(ReportForm, ReportCreated) Export
	
EndProcedure

// The details handler of a spreadsheet document of a report form.
// See "Form field extension for a spreadsheet document field.DetailProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   Item - FormField - a spreadsheet document.
//   Details - Arbitrary     - the details value of a point, series, or a chart value.
//   StandardProcessing - Boolean - a flag of standard (system) event processing execution.
//
Procedure DetailProcessing(ReportForm, Item, Details, StandardProcessing) Export
	DriveReportsClient.DetailProcessing(ReportForm, Item, Details, StandardProcessing);
EndProcedure

// The handler of additional details (menu of a spreadsheet document of a report form).
// See "Form field extension for a spreadsheet document field.AdditionalDetailProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   Item - FormField - a spreadsheet document.
//   Details - Arbitrary     - the details value of a point, series, or a chart value.
//   StandardProcessing - Boolean - a flag of standard (system) event processing execution.
//
Procedure AdditionalDetailProcessing(ReportForm, Item, Details, StandardProcessing) Export
	DriveReportsClient.AdditionalDetailProcessing(ReportForm, Item, Details, StandardProcessing);
EndProcedure

// Handler of commands that were dynamically added and attached to the "Attachable_Command" handler.
// See an example of adding a command in ReportsOverridable.OnGenerateAtServer(). 
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   Command     - FormCommand     - a command that was called.
//   Result   - Boolean           - True if the command call is processed.
//
Procedure CommandHandler(ReportForm, Command, Result) Export
	
	
	
EndProcedure

// Handler of the subordinate form selection result.
//  See "ClientApplicationForm.ChoiceProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm       - ClientApplicationForm - report form.
//   SelectedValue - Arbitrary - a result of the selection in a subordinate form.
//   ChoiceSource - ClientApplicationForm - a form where the choice is made.
//   Result - Boolean - True if the selection result is processed.
//
Procedure ChoiceProcessing(ReportForm, SelectedValue, ChoiceSource, Result) Export
	
EndProcedure

// Handler for double click, clicking Enter, or a hyperlink in a report form spreadsheet document.
// See "Form field extension for a spreadsheet document field.Choice" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   Item - FormField - a spreadsheet document.
//   Area     - SpreadsheetDocumentRange - the selected value.
//   StandardProcessing - Boolean - a flag of standard event processing execution.
//
Procedure SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing) Export
	
EndProcedure

// Handler of report form broadcast notification.
// See "ClientApplicationForm.NotificationProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   EventName  - String           - event ID for receiving forms.
//   Parameter    - Arbitrary     - extended informaion about an event.
//   Source    - ClientApplicationForm, Arbitrary - an event source.
//   NotificationProcessed - Boolean - indicates that an event is processed.
//
Procedure NotificationProcessing(ReportForm, EventName, Parameter, Source, NotificationProcessed) Export
	
EndProcedure

// Handler of clicking the period selection button in a separate form.
//
// Parameters:
//   ReportForm - ClientApplicationForm - a report form.
//   Period - StandardPeriod - composer setting value that matches the selected period.
//   StandardProcessing - Boolean - if True, the standard period selection dialog box will be used.
//       If it is set to False, the standard dialog box will not open.
//   ResultHandler - NotifyDescription - handler of period selection result.
//       The following type values can be passed to the ResultHandler as the result:
//       Undefined - user canceled the period input.
//       StandardPeriod - the selected period.
//
//  If the configuration uses its own period selection dialog box, set the StandardProcessing 
//      parameter to False and return the selected period to ResultHandler.
//      
//
Procedure OnClickPeriodSelectionButton(ReportForm, Period, StandardProcessing, ResultHandler) Export
	
EndProcedure

#EndRegion
