#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	Title = Parameters.ItemType;
	Items.DescriptionForPrinting.Enabled = OutputItemTitle;
	Items.GroupingTitle.Enabled = OutputGroupingTitle;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
	
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
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure OutputItemTitleOnChange(Item)
	
	Items.DescriptionForPrinting.Enabled = OutputItemTitle;
	Object.DescriptionForPrinting = ?(OutputItemTitle, Object.DescriptionForPrinting, "Table");
	
EndProcedure

&AtClient
Procedure OutputGroupingTitleOnChange(Item)
	
	Items.GroupingTitle.Enabled = OutputGroupingTitle;
	If Not OutputGroupingTitle Then
		GroupingTitle = "";
	EndIf;
	
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