#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	BasisStructure = New Structure;
	BasisStructure.Insert("RequestForQuotation", CommandParameter);
	
	SuppliersArray = GetSuppliersFromRFQ(CommandParameter);
	
	If SuppliersArray.Count() > 0 Then
		
		If SuppliersArray.Count() = 1 Then
			
			BasisStructure.Insert("Supplier", SuppliersArray[0]);
			
		Else
			
			SuppliersList = New ValueList;
			SuppliersList.LoadValues(SuppliersArray);
			
			BasisStructure.Insert("CommandExecuteParameters", CommandExecuteParameters);
			NotifyDescription = New NotifyDescription("GenerateRFQResponseEnd", ThisObject, BasisStructure);
			
			SuppliersList.ShowChooseItem(NotifyDescription, NStr("en = 'Choose a supplier from the list'; ru = 'Выберите поставщика из списка';pl = 'Wybierz dostawcę z listy';es_ES = 'Elija un proveedor de la lista';es_CO = 'Elija un proveedor de la lista';tr = 'Listeden bir tedarikçi seçin';it = 'Scegliere un fornitore dall''elenco';de = 'Wählen Sie einen Lieferanten aus der Liste aus'"));
			
			Return;
			
		EndIf;
		
	EndIf;
	
	OpenForm("Document.SupplierQuote.ObjectForm",
		New Structure("Basis", BasisStructure),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateRFQResponseEnd(ItemSelection, AdditionalParameters) Export
	
	If ItemSelection <> Undefined Then
		AdditionalParameters.Insert("Supplier", ItemSelection.Value);
	EndIf;
	
	CommandExecuteParameters = AdditionalParameters.CommandExecuteParameters;
	
	AdditionalParameters.Delete("CommandExecuteParameters");
	
	OpenForm("Document.SupplierQuote.ObjectForm",
		New Structure("Basis", AdditionalParameters),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function GetSuppliersFromRFQ(RequestForQuotationRef)
	
	ResultArray = New Array;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	RequestForQuotationSuppliers.Counterparty AS Counterparty
	|FROM
	|	Document.RequestForQuotation.Suppliers AS RequestForQuotationSuppliers
	|WHERE
	|	RequestForQuotationSuppliers.Ref = &Ref";
	
	Query.SetParameter("Ref", RequestForQuotationRef);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		ResultArray = QueryResult.Unload().UnloadColumn("Counterparty");
	EndIf;
	
	Return ResultArray;
	
EndFunction

#EndRegion
