
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	DontAskAgain = False;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.HowToOpen.Title = NStr("ru ='Режим открытия файла'; en = 'File opening mode'; pl = 'Tryb otwarcia pliku';es_ES = 'Modo de abrir el archivo';es_CO = 'Modo de abrir el archivo';tr = 'Dosya açılış modu';it = 'Modalità di apertura file';de = 'Datei-Öffnungsmodus'");
		Items.HowToOpen.TitleLocation = FormItemTitleLocation.Top;
		Items.HowToOpen.RadioButtonType = RadioButtonType.RadioButton;
		Items.Cancel.Visible = False;
		Items.Help.Visible = False;
		Items.LabelDecoration.Height = 2;
		Items.CommandBarMobileClient.Visible = True;
		Items.OpenFileMobileClient.DefaultButton = True;
		
		CommandBarLocation = FormCommandBarLabelLocation.None;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenFile(Command)
	
	If DontAskAgain = True Then
		CommonServerCall.CommonSettingsStorageSave(
			"OpenFileSettings", "PromptForEditModeOnOpenFile", False,,, True);
		RefreshReusableValues();
	EndIf;
	
	SelectionResult = New Structure;
	SelectionResult.Insert("DontAskAgain", DontAskAgain);
	SelectionResult.Insert("HowToOpen", HowToOpen);
	NotifyChoice(SelectionResult);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	NotifyChoice(DialogReturnCode.Cancel);
EndProcedure

#EndRegion
