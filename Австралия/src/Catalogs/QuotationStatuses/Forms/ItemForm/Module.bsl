
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		
		SetObjectColor(Object.Ref);
		
	Else
		
		If Parameters.Property("CopyingValue") AND ValueIsFilled(Parameters.CopyingValue) Then
		
			SetObjectColor(Parameters.CopyingValue);
			
		EndIf;
		
		SetObjectOrder();
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.HighlightColor = New ValueStorage(Color);
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_QuotationStatuse");
	SetObjectColor(Object.Ref);
	
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
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetObjectColor(QuotationStatusesRef)
	
	Color = QuotationStatusesRef.HighlightColor.Get();
	
EndProcedure

&AtServer
Procedure SetObjectOrder()
	
	Order = 0;
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	QuotationStatuses.Order AS Order
		|FROM
		|	Catalog.QuotationStatuses AS QuotationStatuses
		|WHERE
		|	NOT QuotationStatuses.DeletionMark
		|
		|ORDER BY
		|	Order DESC";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Order = SelectionDetailRecords.Order + 1;
	EndIf;
	
	Object.Order = Order;
	
EndProcedure

#EndRegion

