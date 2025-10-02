import React, { useState } from "react";
import axios from "axios";

const API_URL = "/api";

function AddEmployee({ refreshList }) {
  const [empno, setEmpno] = useState("");
  const [empname, setEmpname] = useState("");
  const [salary, setSalary] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await axios.post(`${API_URL}/employees/add`, { empno, empname, salary });
      alert("Employee added successfully!");
      setEmpno("");
      setEmpname("");
      setSalary("");
      refreshList();
    } catch (err) {
      console.error("Error adding employee:", err);
      alert("Failed to add employee. See console for details.");
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input type="text" placeholder="Emp No" value={empno} onChange={e => setEmpno(e.target.value)} required className="form-control mb-2"/>
      <input type="text" placeholder="Emp Name" value={empname} onChange={e => setEmpname(e.target.value)} required className="form-control mb-2"/>
      <input type="text" placeholder="Salary" value={salary} onChange={e => setSalary(e.target.value)} required className="form-control mb-2"/>
      <button type="submit" className="btn btn-success w-100">Add Employee</button>
    </form>
  );
}

export default AddEmployee;

