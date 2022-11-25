#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AccountingTransactionFieldNames = "AccountingEntriesRecorder";
	
	If StrFind(AccountingTransactionFieldNames, Field.Name) <> 0 Then
		KeyToOpen = Item.CurrentData.AccountingEntriesRecorder;
	Else
		KeyToOpen = Item.CurrentData.SourceDocument;
	EndIf;
	
	If ValueIsFilled(KeyToOpen) Then
		FormParameters = New Structure;
		FormParameters.Insert("Key", KeyToOpen);
		OpenForm("Document." + GetDocumentName(KeyToOpen) + ".ObjectForm",
			FormParameters,
			ThisObject,
			True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetDocumentName(DocumentRef)
	
	Return DocumentRef.Metadata().Name;
	
EndFunction

#EndRegion