
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	QueryConsoleID = "QueryConsole";
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	
	Row = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting);
	If Lower(Right(Row, 4)) = ".epf" Then
		QueryConsoleUsageOption = 0;
	ElsIf Metadata.DataProcessors.Find(Row) <> Undefined Then
		QueryConsoleUsageOption = 1;
		Row = "";	
	Else 
		QueryConsoleUsageOption = 0;
		Row = "";
	EndIf;
	CurrentObject.QueryExternalDataProcessorAddressSetting = Row;
	
	ThisObject(CurrentObject);
	
	ChoiceList = Items.ExternalQueryDataProcessor.ChoiceList;
	
	// The data processor is included in the metadata if it is a predefined part of the configuration.
	If Metadata.DataProcessors.Find(QueryConsoleID) = Undefined Then
		CurItem = ChoiceList.FindByValue(1);
		If CurItem <> Undefined Then
			ChoiceList.Delete(CurItem);
		EndIf;
	EndIf;
	
	Items.QueryConsole.Visible = (ChoiceList.Count() > 0);
	
	// Option string from the file
	If CurrentObject.IsFileInfobase() Then
		CurItem = ChoiceList.FindByValue(2);
		If CurItem <> Undefined Then
			CurItem.Presentation = NStr("ru = 'В каталоге:'; en = 'In directory:'; pl = 'W katalogu:';es_ES = 'En el directorio:';es_CO = 'En el directorio:';tr = 'Dizinde:';it = 'Nella directory:';de = 'Im Verzeichnis:'");
		EndIf;
	EndIf;

	// SSLGroup form item is visible if this SSL version is supported.
	Items.SLGroup.Visible = CurrentObject.ConfigurationSupportsSSL
	
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure ConfirmSelection(Command)
	
	CheckSSL = CheckSettings();
	If CheckSSL.HasErrors Then
		// Reporting errors
		If CheckSSL.QueryExternalDataProcessorAddressSetting <> Undefined Then
			ReportError(CheckSSL.QueryExternalDataProcessorAddressSetting, "Object.QueryExternalDataProcessorAddressSetting");
			Return;
		EndIf;
	EndIf;
	
	// All successful
	SaveSettings();
	Close();
EndProcedure

#EndRegion

#Region Private
//

&AtClient
Procedure ReportError(Text, AttributeName = Undefined)
	
	If AttributeName = Undefined Then
		ErrorTitle = NStr("ru = 'Ошибка'; en = 'Error'; pl = 'Błąd';es_ES = 'Error';es_CO = 'Error';tr = 'Hata';it = 'Errore';de = 'Fehler'");
		ShowMessageBox(, Text, , ErrorTitle);
		Return;
	EndIf;
	
	Message = New UserMessage();
	Message.Text = Text;
	Message.Field  = AttributeName;
	Message.SetData(ThisObject);
	Message.Message();
EndProcedure	

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CheckSettings()
	CurrentObject = ThisObject();
	
	If QueryConsoleUsageOption = 2 Then
		
		CurrentObject.QueryExternalDataProcessorAddressSetting = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting);
		If StrStartsWith(CurrentObject.QueryExternalDataProcessorAddressSetting, """")
			AND StrEndsWith(CurrentObject.QueryExternalDataProcessorAddressSetting, """") Then
			CurrentObject.QueryExternalDataProcessorAddressSetting = Mid(CurrentObject.QueryExternalDataProcessorAddressSetting, 
				2, StrLen(CurrentObject.QueryExternalDataProcessorAddressSetting) - 2);
		EndIf;
		
		If Not StrEndsWith(Lower(TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting)), ".epf") Then
			CurrentObject.QueryExternalDataProcessorAddressSetting = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting) + ".epf";
		EndIf;
		
	ElsIf QueryConsoleUsageOption = 0 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = "";
		
	EndIf;
	
	Result = CurrentObject.CheckSettingCorrectness();
	ThisObject(CurrentObject);
	
	Return Result;
EndFunction

&AtServer
Procedure SaveSettings()
	CurrentObject = ThisObject();
	If QueryConsoleUsageOption = 0 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = "";
	ElsIf QueryConsoleUsageOption = 1 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = QueryConsoleID		;
	EndIf;
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

#EndRegion
