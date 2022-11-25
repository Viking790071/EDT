#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Title = NStr("en = 'Link to a report item'; ru = 'Ссылка на элемент отчета';pl = 'Odnośnik do elementu raportu';es_ES = 'Enlace al elemento del informe';es_CO = 'Enlace al elemento del informe';tr = 'Rapor öğesine bağlantı';it = 'Collegamento a elemento report';de = 'Link zu einer Berichtsposition'");
	
	ObjectData = Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	LinkedReportType = Object.LinkedItem.Owner;
	LinkedItemDescription = Object.LinkedItem.DescriptionForPrinting;
	Description = ObjectData.DescriptionForPrinting;
	If IsBlankString(LinkedItemDescription) And Not IsBlankString(Description) Then
		LinkedItemDescription = ObjectData.DescriptionForPrinting;
	EndIf;
	ItemTypes = Enums.FinancialReportItemsTypes;
	IsIndicator = (ObjectData.ItemType = ItemTypes.AccountingDataIndicator
		Or ObjectData.ItemType = ItemTypes.UserDefinedFixedIndicator
		Or ObjectData.ItemType = ItemTypes.UserDefinedCalculatedIndicator
		Or (ObjectData.ItemType = ItemTypes.GroupTotal And ObjectData.IsLinked));
	
	Items.ReverseSign.Visible = IsIndicator;
	Items.MarkItem.Visible = IsIndicator;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	AddMode = Enums.ReportItemsAdditionalModes.LinkedItem;
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel, AddMode);
	
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

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

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
Procedure LinkedItemClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", LinkedReportType);
	FormParameters.Insert("CurrentReportItem", Object.LinkedItem);
	OpenForm("Catalog.FinancialReportsTypes.ObjectForm", FormParameters);
	
	Close();
	
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
