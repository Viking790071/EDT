#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisForm);
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisForm);
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then 
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	AddEmptyShippingAddress = GetAddEmptyShippingAddress(CurrentData.Ref);
	
	BasisStructure = New Structure();
	BasisStructure.Insert("PackingSlip", CurrentData.Ref);
	
	OrdersArray = GetArraySalesOrder();
	If OrdersArray.Count() = 1 Then
		
		BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
		OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		
	Else
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Company", CurrentData.Company);
		AdditionalParameters.Insert("AddEmptyShippingAddress", AddEmptyShippingAddress);
		
		DataStructure = DriveServer.CheckOrdersKeyAttributes(OrdersArray, AdditionalParameters);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			BasisStructure.Insert("OrdersGroups", DataStructure.OrdersGroups);
			ShowQueryBox(
				New NotifyDescription("CreateSalesInvoices", 
					ThisObject,
					BasisStructure),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then 
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	AddEmptyShippingAddress = GetAddEmptyShippingAddress(CurrentData.Ref);
	
	BasisStructure = New Structure();
	BasisStructure.Insert("PackingSlip", CurrentData.Ref);
	
	OrdersArray = GetArraySalesOrder();
	If OrdersArray.Count() = 1 Then
		
		BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
		OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
		
	Else
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Company", CurrentData.Company);
		AdditionalParameters.Insert("AddEmptyShippingAddress", AddEmptyShippingAddress);
		
		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersArray, AdditionalParameters);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			BasisStructure.Insert("OrdersGroups", DataStructure.OrdersGroups);
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssue",
					ThisObject,
					BasisStructure),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
EndProcedure

&AtServer
Function GetArraySalesOrder()
	
	OrdersArray = New Array;
	PackingSlipArray = New Array;
	
	For Each Row In Items.List.SelectedRows Do
		PackingSlipArray.Add(Row);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED DISTINCT
		|	PackingSlipInventory.SalesOrder AS SalesOrder
		|FROM
		|	Document.PackingSlip.Inventory AS PackingSlipInventory
		|WHERE
		|	PackingSlipInventory.Ref IN(&PackingSlipArray)";
	
	Query.SetParameter("PackingSlipArray", PackingSlipArray);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		OrdersArray.Add(Selection.SalesOrder);
	EndDo;
	
	Return OrdersArray;
	
EndFunction

&AtClient
Procedure CreateGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			FillStructure.Insert("PackingSlip", AdditionalParameters.PackingSlip);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure CreateSalesInvoices(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			FillStructure.Insert("PackingSlip", AdditionalParameters.PackingSlip);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

&AtServerNoContext
Function GetAddEmptyShippingAddress(PackingSlip)

	AddEmptyShippingAddress	= False;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	PackingSlipInventory.Ref AS Ref
	|FROM
	|	Document.PackingSlip.Inventory AS PackingSlipInventory
	|WHERE
	|	PackingSlipInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AddEmptyShippingAddress	= True;
	EndIf;
	
	Return AddEmptyShippingAddress; 

EndFunction

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion
