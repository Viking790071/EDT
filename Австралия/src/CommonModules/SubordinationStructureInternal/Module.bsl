#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.DependenciesUsage";
	NewName  = "Role.ViewRelatedDocuments";
	Common.AddRenaming(Total, "2.3.3.5", OldName, NewName, Library);
	
EndProcedure

#EndRegion
