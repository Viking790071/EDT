#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandartProcessing)
	
	Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	Title = Parameters.ItemType;
	
	FillSubstitutionParameters();
	AddSubstitutionParametersCommands();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandartProcessing)
	
	If ValueIsFilled(ItemAddressInTempStorage) Then
		StandartProcessing = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandartProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure TextOnChange(Item)
	
	Object.DescriptionForPrinting = TrimAll(StrGetLine(Text, 1));
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Command)
	
	FinancialReportingClient.FinishEditingReportItem(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddSubstitutionParametersCommands()
	
	CommandActionName = "AddSubstitutionPattern";
	
	For ParameterNumber = 1 To SubstitutionParameters.Count() Do
		
		PatternParameterName = "AddPattern" + ParameterNumber;
		
		FormCommand = Commands.Add(PatternParameterName);
		FormCommand.Action = CommandActionName;
		
		NewFormButton = Items.Add(PatternParameterName, Type("FormButton"), Items.AddParameter);
		NewFormButton.Title = SubstitutionParameters[ParameterNumber-1].Value;
		NewFormButton.CommandName = PatternParameterName;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillSubstitutionParameters()
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	SubstitutionParameters.Add(
	NStr("en = 'Report type'; ru = '?????? ????????????';pl = 'Typ sprawozdania';es_ES = 'Tipo de informe';es_CO = 'Tipo de informe';tr = 'Rapor t??r??';it = 'Tipo di report';de = 'Berichtstyp'"),
	NStr("en = 'Report type'; ru = '?????? ????????????';pl = 'Typ sprawozdania';es_ES = 'Tipo de informe';es_CO = 'Tipo de informe';tr = 'Rapor t??r??';it = 'Tipo di report';de = 'Berichtstyp'", DefaultLanguageCode));
	
	SubstitutionParameters.Add(
	NStr("en = 'Current date and time'; ru = '?????????????? ???????? ?? ??????????';pl = 'Aktualna data i godzina';es_ES = 'Fecha y hora actuales';es_CO = 'Fecha y hora actuales';tr = 'G??ncel tarih ve saat';it = 'Data e orario corrente';de = 'Aktuelles Datum und Uhrzeit'"),
	NStr("en = 'Current date and time'; ru = '?????????????? ???????? ?? ??????????';pl = 'Aktualna data i godzina';es_ES = 'Fecha y hora actuales';es_CO = 'Fecha y hora actuales';tr = 'G??ncel tarih ve saat';it = 'Data e orario corrente';de = 'Aktuelles Datum und Uhrzeit'", DefaultLanguageCode));
	
	SubstitutionParameters.Add(
	NStr("en = 'Report period'; ru = '???????????? ????????????';pl = 'Okres sprawozdawczy';es_ES = 'Per??odo de informes';es_CO = 'Per??odo de informes';tr = 'Rapor d??nemi';it = 'Periodo report';de = 'Berichtszeitraum'"),
	NStr("en = 'Report period'; ru = '???????????? ????????????';pl = 'Okres sprawozdawczy';es_ES = 'Per??odo de informes';es_CO = 'Per??odo de informes';tr = 'Rapor d??nemi';it = 'Periodo report';de = 'Berichtszeitraum'", DefaultLanguageCode));
	
	SubstitutionParameters.Add(
	NStr("en = 'Report period end date'; ru = '???????? ?????????????????? ???????????? ????????????';pl = 'Data zako??czenia okresu sprawozdawczego';es_ES = 'Fecha de fin del per??odo del informe';es_CO = 'Fecha de fin del per??odo del informe';tr = 'Rapor d??nemi biti?? tarihi';it = 'Data di fine periodo del report';de = 'Enddatum des Berichtszeitraums'"),
	NStr("en = 'Report period end date'; ru = '???????? ?????????????????? ???????????? ????????????';pl = 'Data zako??czenia okresu sprawozdawczego';es_ES = 'Fecha de fin del per??odo del informe';es_CO = 'Fecha de fin del per??odo del informe';tr = 'Rapor d??nemi biti?? tarihi';it = 'Data di fine periodo del report';de = 'Enddatum des Berichtszeitraums'", DefaultLanguageCode));
	
	SubstitutionParameters.Add(
	NStr("en = 'Company'; ru = '??????????????????????';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = '???? yeri';it = 'Azienda';de = 'Firma'"),
	NStr("en = 'Company'; ru = '??????????????????????';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = '???? yeri';it = 'Azienda';de = 'Firma'", DefaultLanguageCode));
	
EndProcedure

&AtClient
Procedure AddSubstitutionPattern(Command)
	
	TextToPaste = "[" + SubstitutionParameters.FindByValue(Items[Command.Name].Title).Presentation + "]";
	PasteTextIntoTitle(TextToPaste);
	
EndProcedure

&AtClient
Procedure PasteTextIntoTitle(TextToPaste, Indent = 0)
	
	BegRow = 0;
	EndRow = 0;
	BegColumn = 0;
	EndColumn = 0;
	
	Items.Text.GetTextSelectionBounds(BegRow, BegColumn, EndRow, EndColumn);
	
	If (EndColumn = BegColumn) And (EndColumn + StrLen(TextToPaste)) > Items.Text.Width / 8 Then
		Items.Text.SelectedText = "";
	EndIf;
	
	Items.Text.SelectedText = TextToPaste;
	
	If Not Indent = 0 Then
		Items.Text.GetTextSelectionBounds(BegRow, BegColumn, EndRow, EndColumn);
		Items.Text.SetTextSelectionBounds(BegRow, BegColumn - Indent, EndRow, EndColumn - Indent);
	EndIf;
	CurrentItem = Items.Text;
	
EndProcedure

#EndRegion

