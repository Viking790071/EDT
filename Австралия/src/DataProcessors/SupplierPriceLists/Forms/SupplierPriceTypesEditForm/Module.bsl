
#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Function returns the value array containing tabular section units
//
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow In Object[TabularSectionName] Do		
		ValueArray.Add(TableRow.Ref);		
	EndDo;
	
	Return ValueArray;
	
EndFunction

&AtClient
// Adds array items to the tabular section.
// Preliminary check whether this item is in the tabular section.
//
Procedure AddItemsIntoTabularSection(ItemArray)
	
	If Not TypeOf(ItemArray) = Type("Array") 
		OR Not ItemArray.Count() > 0 Then 
		
		Return;
		
	EndIf;
	
	For Each ArrayElement In ItemArray Do
		
		If Object.SupplierPriceTypes.FindRows(New Structure("Ref", ArrayElement)).Count() > 0 Then
			
			CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Item [%1] is present in the filter.'; ru = 'Позиция [%1] не присутствует в фильтре.';pl = 'Element [%1] już jest w filtrze.';es_ES = 'Artículo [%1] está presente en el filtro.';es_CO = 'Artículo [%1] está presente en el filtro.';tr = 'Filtre içinde [%1] öğesi mevcut.';it = 'Elemento [%1] è presente nel filtro.';de = 'Artikel [%1] ist im Filter vorhanden.'"),
				ArrayElement));
			Continue;
			
		EndIf;
		
		NewRow 		= Object.SupplierPriceTypes.Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ArraySupplierPriceTypes") Then
		
		For Each ItemOfArray In Parameters.ArraySupplierPriceTypes Do
				
			NewRow = Object.SupplierPriceTypes.Add();
			NewRow.Ref = ItemOfArray.Ref;
				
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of form.
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Not TypeOf(ValueSelected) = Type("Array") Then
		
		ChoiceValue		= ValueSelected;
		ValueSelected	= New Array;
		ValueSelected.Add(ChoiceValue);
		
	EndIf;
	
	AddItemsIntoTabularSection(ValueSelected);
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
// Procedure - command handler OK.
//
Procedure OK(Command)
	
	NotifyChoice(FillArrayByTabularSectionAtClient("SupplierPriceTypes"));
	
EndProcedure

&AtClient
// Procedure - Selection command handler.
//
Procedure Pick(Command)
	
	OpenForm("Catalog.SupplierPriceTypes.Form.QuickChoiceForm", New Structure("Multiselect, ChoiceMode, CloseOnChoice", True, True, False), ThisForm);
	
EndProcedure

#EndRegion
