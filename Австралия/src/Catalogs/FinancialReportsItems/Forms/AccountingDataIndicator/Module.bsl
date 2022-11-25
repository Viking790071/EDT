#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ObjectData = Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	
	IsBalance = StrFind(TotalsType, "Balance") > 0;
	Items.PeriodBoundary.Visible = IsBalance;
	CurrentTotalsType = IsBalance;
	If Account <> Undefined Then
		AccountDescription = Common.ObjectAttributeValue(Account, "Description");
		Items.Account.TypeRestriction = FinancialReportingServer.TypeDescriptionByValue(Account);
	EndIf;
	Items.GroupAdditionalAttributes.Visible = Parameters.ShowRowCodeAndNote;
	Items.ReverseSign.Visible = Parameters.ShowRowCodeAndNote;
	Items.MarkItem.Visible = Parameters.ShowRowCodeAndNote;
	RefreshFormTitle();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RefreshFormTitle();

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ValueIsFilled(ItemAddressInTempStorage) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionForPrintingOnChange(Item)
	
	Object.Description = Object.DescriptionForPrinting;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure TotalsTypeOnChange(Item)
	
	IsBalance = StrFind(Item.EditText, "Balance") > 0;
	Items.PeriodBoundary.Visible = IsBalance;
	If CurrentTotalsType <> IsBalance Then
		SetFilterField();
	EndIf;
	CurrentTotalsType = IsBalance;
	
EndProcedure

&AtClient
Procedure AccountOnChange(Item)
	
	AccountOnChangeAtServer();
	
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
Procedure AccountOnChangeAtServer()
	
	NewAccountName = Common.ObjectAttributeValue(Account, "Description");
	If Not ValueIsFilled(Object.DescriptionForPrinting)
		Or Object.DescriptionForPrinting = AccountDescription Then
		Object.DescriptionForPrinting = NewAccountName;
	EndIf;
	Object.Description = Object.DescriptionForPrinting;
	AccountDescription = NewAccountName;
	SetFilterField();
	
EndProcedure

&AtServer
Procedure RefreshFormTitle()
	
	TypePresentation = NStr("en = 'Accounting data indicator'; ru = 'Индикатор учетных данных';pl = 'Wskaźnik danych księgowych';es_ES = 'Indicador de datos contables';es_CO = 'Indicador de datos contables';tr = 'Muhasebe veri göstergesi';it = 'Indicatore dati contabili';de = 'Buchhaltungsdaten Kennzeichen'");
	
	If Not ValueIsFilled(Object.DescriptionForPrinting) Then
		ConcatinatedStrings  = New Array;
		ConcatinatedStrings.Add(TypePresentation);
		ConcatinatedStrings.Add(NStr("en = '(Create)'; ru = '(Создание)';pl = '(Tworzenie)';es_ES = '(Crear)';es_CO = '(Crear)';tr = '(Oluştur)';it = '(Crea)';de = '(Erstellen)'"));
		Title = StrConcat(ConcatinatedStrings, " ");
	Else
		Title = Object.DescriptionForPrinting + " (" + TypePresentation + ")";
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFilterField()
	
	Catalogs.FinancialReportsItems.SetFilterSettings(ThisObject, Composer, Object.ItemType, Composer.Settings);
	
EndProcedure

#EndRegion
