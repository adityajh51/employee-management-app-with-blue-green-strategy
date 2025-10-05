import React, { useState } from "react";
import AddEmployee from "./components/AddEmployee";
import ListEmployees from "./components/ListEmployees";
import 'bootstrap/dist/css/bootstrap.min.css';

function App() {
  const [refreshFlag, setRefreshFlag] = useState(false);
  const refreshList = () => setRefreshFlag(!refreshFlag);

  return (
    <div className="container mt-5">
      <div className="text-center mb-4">
        <h2 className="text-primary fw-bold">Employee Management</h2>
      </div>

      {/* Add Employee Card */}
      <div className="card mb-4 shadow-sm border-success">
        <div className="card-header bg-success text-white">
          Add Employee
        </div>
        <div className="card-body">
          <AddEmployee refreshList={refreshList} />
        </div>
      </div>

      {/* List Employees Card */}
      <div className="card shadow-sm border-primary">
        <div className="card-header bg-primary text-white">
          List of Employees
        </div>
        <div className="card-body">
          <ListEmployees refreshFlag={refreshFlag} />
        </div>
      </div>
    </div>
  );
}

export default App;

