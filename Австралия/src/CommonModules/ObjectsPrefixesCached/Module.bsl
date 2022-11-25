#Region Private

// Returns a table of prefix generating attributes specified in the overridable module.
//
Function PrefixGeneratingAttributes() Export
	
	Objects = New ValueTable;
	Objects.Columns.Add("Object");
	Objects.Columns.Add("Attribute");
	
	ObjectsPrefixesOverridable.GetPrefixGeneratingAttributes(Objects);
	
	ObjectsAttributes = New Map;
	
	For each Row In Objects Do
		ObjectsAttributes.Insert(Row.Object.FullName(), Row.Attribute);
	EndDo;
	
	Return New FixedMap(ObjectsAttributes);
	
EndFunction

#EndRegion
