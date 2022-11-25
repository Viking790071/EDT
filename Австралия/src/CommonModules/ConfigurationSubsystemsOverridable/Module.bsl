#Region Public

// Defines the list of configuration and library modules that provide the following general details: 
// name, version, update handler list, and its dependence on other libraries.
// 
//
// See the composition of the mandatory procedures of such a module in the SLInfobaseUpdate common 
// module (Public area).
// There is no need to add the SLInfobaseUpdate module of the Library of standard subsystems to the 
// SubsystemModules array.
//
// Parameters:
//  SubsystemModules - Array - names of the common server library modules and the configurations.
//                             For example, CRLInfobaseUpdate - library,
//                                       EAInfobaseUpdate - configuration.
//                    
Procedure SubsystemsOnAdd(SubsystemModules) Export
	SubsystemModules.Add("InfobaseUpdateDrive");
EndProcedure

#EndRegion
