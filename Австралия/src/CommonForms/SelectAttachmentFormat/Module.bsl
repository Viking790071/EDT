
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Importing the passed parameters.
	PassedFormatArray = New Array;
	If Parameters.FormatSettings <> Undefined Then
		PassedFormatArray = Parameters.FormatSettings.SaveFormats;
		PackToArchive = Parameters.FormatSettings.PackToArchive;
		TransliterateFilesNames = False;
	EndIf;
	
	// Filling in the format list.
	For Each SaveFormat In StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings() Do
		Mark = False;
		If Parameters.FormatSettings <> Undefined Then 
			PassedFormat = PassedFormatArray.Find(SaveFormat.SpreadsheetDocumentFileType);
			If PassedFormat <> Undefined Then
				Mark = True;
			EndIf;
		EndIf;
		SelectedSaveFormats.Add(SaveFormat.SpreadsheetDocumentFileType, String(SaveFormat.Ref), Mark, SaveFormat.Picture);
	EndDo;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
	Items.TransliterateFilesNames.Visible = False;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	If Parameters.FormatSettings <> Undefined Then
		If Parameters.FormatSettings.SaveFormats.Count() > 0 Then
			Settings.Delete("SelectedSaveFormats");
		EndIf;
		If Parameters.FormatSettings.Property("PackToArchive") Then
			Settings.Delete("PackToArchive");
		EndIf;
		If Parameters.FormatSettings.Property("TransliterateFilesNames") Then
			Settings.Delete("TransliterateFilesNames");
		EndIf;
		Return;
	EndIf;
	
	SaveFormatsFromSettings = Settings["SelectedSaveFormats"];
	If SaveFormatsFromSettings <> Undefined Then
		For Each SelectedFormat In SelectedSaveFormats Do 
			FormatFromSettings = SaveFormatsFromSettings.FindByValue(SelectedFormat.Value);
			SelectedFormat.Check = FormatFromSettings <> Undefined AND FormatFromSettings.Check;
		EndDo;
		Settings.Delete("SelectedSaveFormats");
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetFormatSelection();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	SelectionResult = SelectedFormatSettings();
	NotifyChoice(SelectionResult);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFormatSelection()
	
	HasSelectedFormat = False;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			HasSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not HasSelectedFormat Then
		SelectedSaveFormats[0].Check = True; // The default choice is the first in the list.
	EndIf;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SaveFormats = New Array;
	
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			SaveFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;	
	
	Result = New Structure;
	Result.Insert("PackToArchive", PackToArchive);
	Result.Insert("SaveFormats", SaveFormats);
	Result.Insert("TransliterateFilesNames", TransliterateFilesNames);
	
	Return Result;
	
EndFunction

#EndRegion
