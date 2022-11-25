#Region Private

Function FormCache(Val FormName, Val SourcesCommaSeparated, Val IsObjectForm) Export
	Return New FixedStructure(AttachableCommands.FormCache(FormName, SourcesCommaSeparated, IsObjectForm));
EndFunction

Function Parameters() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Parameters = StandardSubsystemsServer.ApplicationParameter("StandardSubsystems.AttachableCommands");
	If Parameters = Undefined Then
		AttachableCommands.ConfigurationCommonDataNonexclusiveUpdate();
		Parameters = StandardSubsystemsServer.ApplicationParameter("StandardSubsystems.AttachableCommands");
		If Parameters = Undefined Then
			Return New FixedStructure("AttachedObjects", New Map);
		EndIf;
	EndIf;
	
	If ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(AttachableCommands.FullSubsystemName());
		If ExtensionParameters = Undefined Then
			AttachableCommands.OnFillAllExtensionsParameters();
			ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(AttachableCommands.FullSubsystemName());
			If ExtensionParameters = Undefined Then
				Return New FixedStructure(Parameters);
			EndIf;
		EndIf;
		SupplementMapWithArrays(Parameters.AttachedObjects, ExtensionParameters.AttachedObjects);
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return New FixedStructure(Parameters);
EndFunction

Procedure SupplementMapWithArrays(DestinationMap, SourceMap)
	For Each KeyAndValue In SourceMap Do
		DestinationArray = DestinationMap[KeyAndValue.Key];
		If DestinationArray = Undefined Then
			DestinationMap.Insert(KeyAndValue.Key, KeyAndValue.Value);
		Else
			For Each Value In KeyAndValue.Value Do
				If DestinationArray.Find(Value) = Undefined Then
					DestinationArray.Add(Value);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
EndProcedure

#EndRegion
