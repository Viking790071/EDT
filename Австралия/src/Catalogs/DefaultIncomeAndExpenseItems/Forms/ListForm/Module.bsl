
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("FromMapping", FromMapping);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure ListOnChange(Item)
	
	If Item.CurrentData <> Undefined And FromMapping
				And Item.CurrentData.Ref = PredefinedValue("Catalog.DefaultIncomeAndExpenseItems.OtherExpenses") Then
		OtherExpenses = Item.CurrentData.IncomeAndExpenseItem;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not Exit And FromMapping Then
		StandardProcessing = False;
		Close(New Structure("OtherExpenses", OtherExpenses));
	EndIf;
	
EndProcedure

#EndRegion

