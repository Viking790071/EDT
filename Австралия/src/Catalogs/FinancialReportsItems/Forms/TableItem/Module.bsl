#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	FormAdditionalMode = Parameters.FormAdditionalMode;
	Items.GroupAdditionalAttributes.Visible = Parameters.ShowRowCodeAndNote And Parameters.IsRows;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel, FormAdditionalMode);
	
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
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Commands)
	
	FinancialReportingClient.FinishEditingReportItem(ThisObject);
	
EndProcedure

#EndRegion
