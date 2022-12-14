#Region Public

// Creates a new structure of parameters for importing data from a file to a tabular section.
//
// Returns:
//   Structure - parameters for opening the form for importing data to a tabular section:
//    * FullTabularSectionName - String - a full path to the document tabular section formatted as 
//                                           DocumentName.TabularSectionName.
//    * Header - String - a header of the form for importing data from a file.
//    * DataStructureTemplateName - String - a data input template name.
//    * Presentation - String - a window header in the data import form.
//    * AdditionalParameters - AnyType - any additional information that will be passed to the data 
//                                           mapping procedure.
//
Function DataImportParameters() Export
	ImportParameters = New Structure();
	ImportParameters.Insert("FullTabularSectionName");
	ImportParameters.Insert("Title");
	ImportParameters.Insert("DataStructureTemplateName");
	ImportParameters.Insert("AdditionalParameters");
	ImportParameters.Insert("TemplateColumns");
	
	Return ImportParameters;
EndFunction

// Opens the data import form for filling the tabular section.
//
// Parameters:
//   ImportParameters - Structure - see ImportDataFromFileClient.DataImportParameters. 
//   ImportNotification - NotifyDescription - the procedure called to add the imported data to the 
//                                               tabular section.
//
Procedure ShowImportForm(ImportParameters, ImportNotification) Export
	
	OpenForm("DataProcessor.ImportDataFromFile.Form", ImportParameters, 
		ImportNotification.Module, , , , ImportNotification);
		
EndProcedure


#EndRegion

#Region Internal

// Opens the data import form to fill in a tabular section of link mapping in the "Report options" subsystem.
//
// Parameters:
//   ImportParameters - Structure - see ImportDataFromFileClient.DataImportParameters. 
//   ImportNotification - NotifyDescription - the procedure called to add the imported data to the 
//                                               tabular section.
//
Procedure ShowRefFillingForm(ImportParameters, ImportNotification) Export
	
	OpenForm("DataProcessor.ImportDataFromFile.Form", ImportParameters,
		ImportNotification.Module,,,, ImportNotification);
		
EndProcedure

#EndRegion

#Region Private

// Opens a file import dialog.
//
// Parameters:
//  CompletionNotification - NotifyDescription - the procedure to call when a file is successfully put in a storage.
//  FileName	 - String - a file name in the dialog.
//
Procedure FileImportDialog(CompletionNotification , FileName = "") Export
	SelectFileDialog = New Structure();
	SelectFileDialog.Insert("Mode", FileDialogMode.Open);
	SelectFileDialog.Insert("Filter", NStr("ru='?????? ???????????????????????????? ?????????????? ????????????(*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|?????????? Excel 97 (*.xls)|*.xls|?????????? Excel 2007 (*.xlsx)|*.xlsx|?????????????????????? ?????????????? OpenDocument (*.ods)|*.ods|?????????????????? ???????????????? c ?????????????????????????? (*.csv)|*.csv|?????????????????? ???????????????? (*.mxl)|*.mxl'; en = 'All supported file formats(*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Excel Workbook 97 (*.xls)|*.xls|Excel Workbook 2007 (*.xlsx)|*.xlsx|OpenDocument Spreadsheet (*.ods)|*.ods|Delimited text document (*.csv)|*.csv|Spreadsheet document (*.mxl)|*.mxl'; pl = 'Wszystkie obs??ugiwane formaty plik??w(*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Ksi??ga Excel 97 (*.xls)|*.xls|Ksi??ga Excel 2007 (*.xlsx)|*.xlsx|Tabela elektroniczna OpenDocument (*.ods)|*.ods|Dokument tekstowy z rozdzielaczami (*.csv)|*.csv|Dokument tablicowy (*.mxl)|*.mxl';es_ES = 'Todos los formatos de archivos admitidos(*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Libro Excel 97 (*.xls)|*.xls|Libro Excel 2007 (*.xlsx)|*.xlsx|Tabla electr??nica OpenDocument (*.ods)|*.ods|Documento de texto con separadores (*.csv)|*.csv|Documento de tabla (*.mxl)|*.mxl';es_CO = 'Todos los formatos de archivos admitidos(*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Libro Excel 97 (*.xls)|*.xls|Libro Excel 2007 (*.xlsx)|*.xlsx|Tabla electr??nica OpenDocument (*.ods)|*.ods|Documento de texto con separadores (*.csv)|*.csv|Documento de tabla (*.mxl)|*.mxl';tr = 'T??m desteklenen dosya formatlar?? (*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Excel 97 kitab?? (*.xls)|*.xls| Excel 2007 kitab?? (*.xlsx)|*.xlsx|Elektronik tablo OpenDocument (*.ods)|*.ods|Virg??llerle ayr??lm???? de??erler dosyas?? (*.csv)|*.csv|Tablo belgesi (*.mxl)|*.mxl';it = 'Tutti i formati file supportati(*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Excel Workbook 97 (*.xls)|*.xls|Excel Workbook 2007 (*.xlsx)|*.xlsx|OpenDocument Spreadsheet (*.ods)|*.ods|Delimited text document (*.csv)|*.csv|Foglio di calcolo (*.mxl)|*.mxl';de = 'Alle unterst??tzten Dateiformate (*.xls;*.xlsx;*.ods;*.mxl;*.csv)|*.xls;*.xlsx;*.ods;*.mxl;*.csv|Excel 97 (*.xls)|*.xls|Excel 2007 (*.xlsx)|*.xlsx|OpenDocument Tabellenkalkulation (*.ods)|*.ods|Textdokument mit Trennzeichen (*.csv)|*.csv|Tabellendokument (*.mxl)|*.mxl'"));
	
	ID = New UUID(CompletionNotification .Module.UniqueKey);
	StandardSubsystemsClient.ShowPutFile(CompletionNotification , ID, FileName, SelectFileDialog);
EndProcedure

#EndRegion
