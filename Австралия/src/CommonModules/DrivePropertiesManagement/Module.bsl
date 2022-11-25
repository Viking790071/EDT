////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fill property value tree on the object form.
//
Function FillValuesPropertiesTree(Ref, AdditionalAttributes, ForAdditionalAttributes, Sets) Export
	
	If TypeOf(Sets) = Type("ValueList") Then
		PrListOfSets = Sets;
	Else
		PrListOfSets = New ValueList;
		If Sets <> Undefined Then
			PrListOfSets.Add(Sets);
		EndIf;
	EndIf;
	
	Tree = GetTreeForEditPropertiesValues(PrListOfSets, AdditionalAttributes, ForAdditionalAttributes);
	
	Return Tree;
EndFunction

// Fill tabular section of propety value object from property value tree on form.
//
Procedure MovePropertiesValues(AdditionalAttributes, PropertyTree) Export
	
	Values = New Map;
	FillPropertyValuesFromTree(PropertyTree.Rows, Values);
	
	AdditionalAttributes.Clear();
	For Each Str In Values Do
		NewRow = AdditionalAttributes.Add();
		NewRow.Property = Str.Key;
		NewRow.Value = Str.Value;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// Copy necessary strings from formed value tree to another tree.
//
Procedure CopyStringValuesTree(RowsWhereTo, RowsFrom, Parent)
	
	For Each Str In RowsFrom Do
		If Str.Property = Parent Then
			CopyStringValuesTree(RowsWhereTo, Str.Rows, Str.Property);
		Else
			NewRow = RowsWhereTo.Add();
			FillPropertyValues(NewRow, Str);
			CopyStringValuesTree(NewRow.Rows, Str.Rows, Str.Property);
		EndIf;
		
	EndDo;
	
EndProcedure

// Form property value tree to edit in object form.
//
Function GetTreeForEditPropertiesValues(PrListOfSets, propertiesTab, ForAddDetails)
	
	PrLstSelected = New ValueList;
	For Each Str In propertiesTab Do
		If PrListOfSets.FindByValue(Str.Property) = Undefined Then
			PrLstSelected.Add(Str.Property);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalAttributesAndInformation.Ref AS Property,
	|	AdditionalAttributesAndInformation.ValueType AS PropertyValueType,
	|	AdditionalAttributesAndInformation.FormatProperties AS FormatProperties,
	|	Properties.LineNumber AS LineNumber,
	|	CASE
	|		WHEN Properties.Error
	|			THEN 1
	|		ELSE -1
	|	END AS PictureNumber
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|		INNER JOIN (SELECT DISTINCT
	|			PropertiesSetsContent.Property AS Property,
	|			FALSE AS Error,
	|			PropertiesSetsContent.LineNumber AS LineNumber
	|		FROM
	|			Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesSetsContent
	|		WHERE
	|			PropertiesSetsContent.Ref IN(&PrListOfSets)
	|			AND PropertiesSetsContent.Property.IsAdditionalInfo = &ThisIsAdditionalInformation
	|		
	|		UNION
	|		
	|		SELECT
	|			AdditionalAttributesAndInformation.Ref,
	|			TRUE,
	|			PropertiesSetsContent.LineNumber
	|		FROM
	|			ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|				LEFT JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesSetsContent
	|				ON (PropertiesSetsContent.Property = AdditionalAttributesAndInformation.Ref)
	|					AND (PropertiesSetsContent.Ref IN (&PrListOfSets))
	|		WHERE
	|			AdditionalAttributesAndInformation.Ref IN(&PrLstSelected)
	|			AND (PropertiesSetsContent.Ref IS NULL
	|					OR AdditionalAttributesAndInformation.IsAdditionalInfo <> &ThisIsAdditionalInformation)) AS Properties
	|		ON AdditionalAttributesAndInformation.Ref = Properties.Property
	|
	|ORDER BY
	|	Properties.LineNumber";
	
	Query.SetParameter("ThisIsAdditionalInformation", Not ForAddDetails);
	Query.SetParameter("PrListOfSets", PrListOfSets);
	Query.SetParameter("PrLstSelected", PrLstSelected);
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Tree.Columns.Insert(2, "Value", Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.Type);
	
	NewTree = New ValueTree;
	For Each Column In Tree.Columns Do
		NewTree.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	CopyStringValuesTree(NewTree.Rows, Tree.Rows, ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef());
	
	For Each Str In propertiesTab Do
		StrD = NewTree.Rows.Find(Str.Property, "Property", True);
		If StrD <> Undefined Then
			StrD.Value = Str.Value;
		EndIf;
	EndDo;
	
	Return NewTree;
	
EndFunction

// Fill the matching by the rows of the property values tree with non-empty values.
//
Procedure FillPropertyValuesFromTree(TreeRows, Values)
	
	For Each Str In TreeRows Do
		If ValueIsFilled(Str.Value) Then
			Values.Insert(Str.Property, Str.Value);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion