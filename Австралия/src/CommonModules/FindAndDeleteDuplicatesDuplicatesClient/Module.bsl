#Region Public

// Opens a form to merge items of catalogs, charts of characteristic types, calculation types, and accounts.
//
// Parameters:
//     ItemsToMerge - FormTable, Array, ValueList - a list of items to merge.
//                            You can also pass any item collection with the Reference attribute.
//
Procedure MergeSelectedItems(Val ItemsToMerge) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefSet", RefsArray(ItemsToMerge));
	OpenForm("DataProcessor.ReplaceAndMergeItems.Form.ItemsMerge", FormParameters); 
	
EndProcedure

// Opens a form to replace and delete items of catalogs, charts of characteristic types, calculation types, and accounts.
//
// Parameters:
//     ReplacedItems - FormTable, Array, ValueList - a list of items to replace and delete.
//                          You can also pass any item collection with the Reference attribute.
//
Procedure ReplaceSelected(Val ReplacedItems) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefSet", RefsArray(ReplacedItems));
	FormParameters.Insert("OpenByScenario");
	OpenForm("DataProcessor.ReplaceAndMergeItems.Form.ItemsReplacement", FormParameters); 
	
EndProcedure

// Opens the report on reference usage instances.
// Auxiliary data (such as record sets with master dimension, etc.) is not included into the report.
//
// Parameters:
//     Items - FormTable, FormDataCollection, Array, ValueList - a list of items to analyze.
//         You can also pass any item collection with the Reference attribute.
//     OpeningParameters - Structure - optional. Form opening parameters. Contains a set of optional fields.
//         Owner, Uniqueness, Window, URL, OnCloseNotifyDetails, WindowOpeningMode corresponding to 
//         the OpenForm function parameters.
// 
Procedure ShowUsageInstances(Val Items, Val OpeningParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure);
	FormParameters.Filter.Insert("RefSet", RefsArray(Items));
	
	FormOpenParameters = New Structure("Owner, Uniqueness, Window, URL, OnCloseNotifyDescription, WindowOpeningMode");
	If OpeningParameters <> Undefined Then
		FillPropertyValues(FormOpenParameters, OpeningParameters);
	EndIf;
	
	OpenForm(
		"Report.SearchForReferences.Form",
		FormParameters,
		FormOpenParameters.Owner,
		FormOpenParameters.Uniqueness,
		FormOpenParameters.Window,
		FormOpenParameters.URL,
		FormOpenParameters.OnCloseNotifyDescription,
		FormOpenParameters.WindowOpeningMode);
	
EndProcedure

#EndRegion

#Region Internal

Function SearchAndDeletionOfDuplicatesDataProcessorFormName() Export
	Return "DataProcessor.DuplicateObjectDetection.Form.SearchForDuplicates";
EndFunction

#EndRegion

#Region Private

Function RefsArray(Val Items)
	
	ParameterType = TypeOf(Items);
	
	If TypeOf(Items) = Type("FormTable") Then
		
		References = New Array;
		For Each Item In Items.SelectedRows Do
			RowData = Items.RowData(Item);
			If RowData <> Undefined Then
				References.Add(RowData.Ref);
			EndIf;
		EndDo;
		
	ElsIf TypeOf(Items) = Type("FormDataCollection") Then
		
		References = New Array;
		For Each RowData In Items Do
			References.Add(RowData.Ref);
		EndDo;
		
	ElsIf ParameterType = Type("ValueList") Then
		
		References = New Array;
		For Each Item In Items Do
			References.Add(Item.Value);
		EndDo;
		
	Else
		References = Items;
		
	EndIf;
	
	Return References;
EndFunction

#EndRegion
